# Chart DSL Refactoring - Type-Specific Chart Definitions

## Project Overview

**Objective**: Restructure AshReports DSL to support standalone, type-specific chart definitions with nested config sections validated against Contex library options.

**Breaking Changes**: Yes - this is a major refactoring with no backward compatibility.

**Estimated Duration**: 24-32 hours

**Target Structure**:
```elixir
reports do
  # Global standalone chart definitions
  bar_chart :sales_by_region do
    data_source expr(aggregate_sales_by_region())
    config do
      width 600
      height 400
      title "Sales by Region"
      type :grouped
      orientation :vertical
      data_labels true
    end
  end

  # Reports reference charts by name
  report :monthly_report do
    bands do
      band :summary do
        elements do
          bar_chart :sales_by_region
        end
      end
    end
  end
end
```

---

## Section 1: Type-Specific Config Structs ✅ COMPLETE

**Duration**: 2-3 hours (Actual: 2.5 hours)
**Completed**: 2025-10-30
**Branch**: `feature/chart-config-structs`
**Summary**: `notes/features/section1-chart-config-structs-summary.md`

**Goal**: Create individual config structs for each chart type with Contex-validated options, replacing the generic `AshReports.Charts.Config`.

### Task 1.1: Create BarChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/bar_chart_config.ex`
- **Commit**: b4b772b
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add fields: width (default: 600), height (default: 400)
  - [x] Add field: title (string, optional)
  - [x] Add field: type (enum: :simple, :grouped, :stacked, default: :simple)
  - [x] Add field: orientation (enum: :vertical, :horizontal, default: :vertical)
  - [x] Add field: data_labels (boolean, default: true)
  - [x] Add field: padding (integer, default: 2)
  - [x] Add field: colours (array of strings, default: [])
  - [x] Add moduledoc with Contex mapping documentation
  - [x] Add changeset function with validation

### Task 1.2: Create LineChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/line_chart_config.ex`
- **Commit**: e8c9e01
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add common fields: width, height, title, colours
  - [x] Add field: smoothed (boolean, default: true)
  - [x] Add field: stroke_width (string, default: "2")
  - [x] Add field: axis_label_rotation (enum: :auto, :"45", :"90", default: :auto)
  - [x] Add moduledoc with Contex LinePlot documentation
  - [x] Add changeset function

### Task 1.3: Create PieChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/pie_chart_config.ex`
- **Commit**: 61daa97
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add fields: width (default: 600), height (default: 400)
  - [x] Add field: title (string, optional)
  - [x] Add field: data_labels (boolean, default: true)
  - [x] Add field: colours (array of strings, default: [])
  - [x] Add moduledoc with Contex PieChart documentation
  - [x] Add changeset function

### Task 1.4: Create AreaChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/area_chart_config.ex`
- **Commit**: 1cb5438
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add all LineChartConfig fields (inherits behavior)
  - [x] Add field: mode (enum: :simple, :stacked, default: :simple)
  - [x] Add field: opacity (float 0.0-1.0, default: 0.7)
  - [x] Add field: smooth_lines (boolean, default: true)
  - [x] Add moduledoc explaining LinePlot + area fill
  - [x] Add changeset function

### Task 1.5: Create ScatterChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/scatter_chart_config.ex`
- **Commit**: e68a7e5
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add fields: width, height, title, colours
  - [x] Add field: axis_label_rotation (enum, default: :auto)
  - [x] Add moduledoc with Contex PointPlot documentation
  - [x] Add changeset function

### Task 1.6: Create GanttChartConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/gantt_chart_config.ex`
- **Commit**: feb1628
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add fields: width (default: 600), height (default: 400)
  - [x] Add field: title (string, optional)
  - [x] Add field: show_task_labels (boolean, default: true)
  - [x] Add field: padding (integer, default: 2)
  - [x] Add field: colours (array of strings, default: [])
  - [x] Add moduledoc with DateTime requirements warning
  - [x] Add changeset function

### Task 1.7: Create SparklineConfig struct ✅
- **File**: `lib/ash_reports/charts/configs/sparkline_config.ex`
- **Commit**: 768000d
- **Subtasks**:
  - [x] Define Ecto embedded schema
  - [x] Add field: width (integer, default: 100)
  - [x] Add field: height (integer, default: 20)
  - [x] Add field: spot_radius (integer, default: 2)
  - [x] Add field: spot_colour (string, default: "red")
  - [x] Add field: line_width (integer, default: 1)
  - [x] Add field: line_colour (string, default: "rgba(0, 200, 50, 0.7)")
  - [x] Add field: fill_colour (string, default: "rgba(0, 200, 50, 0.2)")
  - [x] Add moduledoc noting compact size defaults
  - [x] Add changeset function

**Results**:
- ✅ All 7 config structs created (763 lines of code)
- ✅ Clean compilation of new files
- ✅ All 201 chart tests passing
- ✅ 7 atomic commits with clear messages
- ✅ Comprehensive documentation with DSL examples

---

## Section 2: Chart Definition Modules ✅ COMPLETE

**Duration**: 2-3 hours (Actual: 1 hour)
**Completed**: 2025-10-31
**Branch**: `feature/chart-definition-modules`
**Summary**: `notes/features/section2-chart-definition-modules-summary.md`

**Goal**: Create struct modules for each chart type that hold the chart definition (name, data_source, config).

### Task 2.1: Create BarChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/bar_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with BarChartConfig.t()
  - [x] Add moduledoc with DSL usage example
  - [x] Add new/2 constructor function

### Task 2.2: Create LineChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/line_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with LineChartConfig.t()
  - [x] Add moduledoc with DSL usage example
  - [x] Add new/2 constructor

### Task 2.3: Create PieChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/pie_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with PieChartConfig.t()
  - [x] Add moduledoc
  - [x] Add new/2 constructor

### Task 2.4: Create AreaChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/area_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with AreaChartConfig.t()
  - [x] Add moduledoc
  - [x] Add new/2 constructor

### Task 2.5: Create ScatterChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/scatter_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with ScatterChartConfig.t()
  - [x] Add moduledoc
  - [x] Add new/2 constructor

### Task 2.6: Create GanttChart definition module ✅
- **File**: `lib/ash_reports/charts/definitions/gantt_chart.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with GanttChartConfig.t()
  - [x] Add moduledoc
  - [x] Add new/2 constructor

### Task 2.7: Create Sparkline definition module ✅
- **File**: `lib/ash_reports/charts/definitions/sparkline.ex`
- **Commit**: 5a1ecd3
- **Subtasks**:
  - [x] Define defstruct with: name, data_source, config
  - [x] Add @type spec with SparklineConfig.t()
  - [x] Add moduledoc
  - [x] Add new/2 constructor

**Results**:
- ✅ All 7 chart definition modules created (610 lines of code)
- ✅ Clean compilation with --warnings-as-errors
- ✅ Removed 4 unused functions (cleanup commit 9f292da)
- ✅ Consistent structure across all modules
- ✅ Comprehensive documentation with DSL examples
- ✅ 2 atomic commits with clear messages

---

## Section 3: DSL Standalone Chart Entities ✅ COMPLETE

**Duration**: 4-5 hours (Actual: 2 hours)
**Completed**: 2025-10-31
**Branch**: `feature/chart-dsl-entities`
**Summary**: `notes/features/section3-chart-dsl-entities-summary.md`

**Goal**: Add standalone chart entity definitions to the reports DSL section so charts can be defined at the top level.

### Task 3.1: Add chart entities to reports section ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Location**: `reports_section/0` function
- **Subtasks**:
  - [x] Add bar_chart_entity() to entities list
  - [x] Add line_chart_entity() to entities list
  - [x] Add pie_chart_entity() to entities list
  - [x] Add area_chart_entity() to entities list
  - [x] Add scatter_chart_entity() to entities list
  - [x] Add gantt_chart_entity() to entities list
  - [x] Add sparkline_entity() to entities list

### Task 3.2: Create bar_chart_entity function ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 095d640
- **Subtasks**:
  - [x] Define Entity struct with name: :bar_chart
  - [x] Set target: AshReports.Charts.BarChart
  - [x] Set args: [:name]
  - [x] Define schema with name and data_source fields
  - [x] Add nested entities: config: [bar_chart_config_entity()]
  - [x] Add examples in moduledoc

### Task 3.3: Create bar_chart_config_entity function ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 095d640
- **Subtasks**:
  - [x] Define Entity struct with name: :config
  - [x] Set target: AshReports.Charts.BarChartConfig
  - [x] Define schema with all BarChartConfig fields
  - [x] Add type validation: {:in, [:simple, :grouped, :stacked]}
  - [x] Add orientation validation: {:in, [:vertical, :horizontal]}
  - [x] Set appropriate defaults

### Task 3.4: Create line_chart_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: ab0054a
- **Subtasks**:
  - [x] Define line_chart_entity with args and schema
  - [x] Define line_chart_config_entity with LineChartConfig fields
  - [x] Add smoothed, stroke_width, axis_label_rotation fields
  - [x] Set defaults

### Task 3.5: Create pie_chart_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d01e181
- **Subtasks**:
  - [x] Define pie_chart_entity
  - [x] Define pie_chart_config_entity with PieChartConfig fields
  - [x] Set defaults

### Task 3.6: Create area_chart_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 96a8170
- **Subtasks**:
  - [x] Define area_chart_entity
  - [x] Define area_chart_config_entity with AreaChartConfig fields
  - [x] Add mode, opacity, smooth_lines fields
  - [x] Set defaults

### Task 3.7: Create scatter_chart_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 4bf5413
- **Subtasks**:
  - [x] Define scatter_chart_entity
  - [x] Define scatter_chart_config_entity with ScatterChartConfig fields
  - [x] Set defaults

### Task 3.8: Create gantt_chart_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 1e35b33
- **Subtasks**:
  - [x] Define gantt_chart_entity
  - [x] Define gantt_chart_config_entity with GanttChartConfig fields
  - [x] Add show_task_labels, padding fields
  - [x] Set defaults

### Task 3.9: Create sparkline_entity and config_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: 77e6a54
- **Subtasks**:
  - [x] Define sparkline_entity
  - [x] Define sparkline_config_entity with SparklineConfig fields
  - [x] Add spot_radius, colours, line_width fields
  - [x] Set compact defaults (100×20)

**Results**:
- ✅ All 7 chart types have DSL entities (+668 lines)
- ✅ Clean compilation with --warnings-as-errors
- ✅ 14 entity functions (7 chart + 7 config)
- ✅ 14 schema functions (7 chart + 7 config)
- ✅ Consistent structure and comprehensive documentation
- ✅ 7 atomic commits with clear messages
- ✅ 50% faster than estimated (2hrs vs 4-5hrs)
## Section 4: Type-Specific Chart Elements in Bands ✅ COMPLETE

**Duration**: 3-4 hours (Actual: 1 hour)
**Completed**: 2025-10-31
**Branch**: `feature/band-chart-elements`
**Summary**: `notes/features/section4-band-chart-elements-summary.md`

**Goal**: Replace the generic chart element with type-specific chart reference elements in bands.

### Task 4.1: Remove old chart_element_entity ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Location**: `band_entity/0` function, entities list
- **Subtasks**:
  - [x] Remove chart_element_entity() from elements list
  - [x] Verify no other references to chart_element_entity
  - [x] Delete chart_element_entity/0 function
  - [x] Delete chart_element_schema/0 function

### Task 4.2: Add bar_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define bar_chart_element_entity function
  - [x] Set name: :bar_chart
  - [x] Set target: AshReports.Element.BarChartElement
  - [x] Set args: [:chart_name]
  - [x] Add schema with chart_name field (references standalone chart)
  - [x] Include base_element_schema() for position, style, conditional
  - [x] Add to band_entity elements list

### Task 4.3: Add line_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define line_chart_element_entity
  - [x] Set target: AshReports.Element.LineChartElement
  - [x] Add schema with chart_name reference
  - [x] Add to band_entity elements list

### Task 4.4: Add pie_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define pie_chart_element_entity
  - [x] Set target: AshReports.Element.PieChartElement
  - [x] Add to band_entity elements list

### Task 4.5: Add area_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define area_chart_element_entity
  - [x] Set target: AshReports.Element.AreaChartElement
  - [x] Add to band_entity elements list

### Task 4.6: Add scatter_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define scatter_chart_element_entity
  - [x] Set target: AshReports.Element.ScatterChartElement
  - [x] Add to band_entity elements list

### Task 4.7: Add gantt_chart_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define gantt_chart_element_entity
  - [x] Set target: AshReports.Element.GanttChartElement
  - [x] Add to band_entity elements list

### Task 4.8: Add sparkline_element_entity to bands ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define sparkline_element_entity
  - [x] Set target: AshReports.Element.SparklineElement
  - [x] Add to band_entity elements list

**Results**:
- ✅ All 7 chart element entities added to band DSL (+137 lines)
- ✅ All 7 element modules created (+526 lines)
- ✅ Clean compilation with --warnings-as-errors
- ✅ Removed deprecated chart_element_entity and schema
- ✅ Comprehensive documentation with DSL examples
- ✅ 1 atomic commit with clear message
- ✅ 67% faster than estimated (1hr vs 3-4hrs)
- ✅ Section 7 (Chart Element Modules) integrated and completed

---

## Section 5: Update Chart Type Implementations ✅ COMPLETE

**Duration**: 2-3 hours (Actual: 1.5 hours)
**Completed**: 2025-10-31
**Branch**: `feature/chart-type-implementations`
**Summary**: `notes/features/section5-chart-type-implementations-summary.md`

**Goal**: Update chart type modules to accept type-specific config structs instead of generic Config.

### Task 5.1: Update BarChart implementation ✅
- **File**: `lib/ash_reports/charts/types/bar_chart.ex`
- **Commit**: 734bf09
- **Subtasks**:
  - [x] Change build/2 signature to accept BarChartConfig
  - [x] Update config field mappings to use BarChartConfig struct
  - [x] Map config.type to Contex :type option
  - [x] Map config.orientation to Contex :orientation option
  - [x] Map config.data_labels to Contex :data_labels option
  - [x] Map config.padding to Contex :padding option
  - [x] Add build_contex_options/1 helper
  - [x] Remove deprecated Contex function calls

### Task 5.2: Update LineChart implementation ✅
- **File**: `lib/ash_reports/charts/types/line_chart.ex`
- **Commit**: f415bca
- **Subtasks**:
  - [x] Change build/2 signature to accept LineChartConfig
  - [x] Map config.smoothed to Contex :smoothed option
  - [x] Map config.stroke_width to Contex :stroke_width option
  - [x] Map config.axis_label_rotation to Contex option
  - [x] Add build_contex_options/4 helper

### Task 5.3: Update PieChart implementation ✅
- **File**: `lib/ash_reports/charts/types/pie_chart.ex`
- **Commit**: cc3bc68
- **Subtasks**:
  - [x] Change build/2 signature to accept PieChartConfig
  - [x] Map config.data_labels to Contex option
  - [x] Add build_contex_options/4 helper

### Task 5.4: Update AreaChart implementation ✅
- **File**: `lib/ash_reports/charts/types/area_chart.ex`
- **Commit**: ee1d62c
- **Subtasks**:
  - [x] Change build/2 signature to accept AreaChartConfig
  - [x] Map config.mode to area_chart_meta for SVG processing
  - [x] Map config.opacity to area_chart_meta
  - [x] Map config.smooth_lines to LinePlot smoothed
  - [x] Add build_contex_options/5 helper

### Task 5.5: Update ScatterPlot implementation ✅
- **File**: `lib/ash_reports/charts/types/scatter_plot.ex`
- **Commit**: cbd648a
- **Subtasks**:
  - [x] Change build/2 signature to accept ScatterChartConfig
  - [x] Map config.axis_label_rotation to Contex option
  - [x] Add build_contex_options/4 helper

### Task 5.6: Update GanttChart implementation ✅
- **File**: `lib/ash_reports/charts/types/gantt_chart.ex`
- **Commit**: c7269a7
- **Subtasks**:
  - [x] Change build/2 signature to accept GanttChartConfig
  - [x] Map config.show_task_labels to Contex option
  - [x] Map config.padding to Contex option
  - [x] Update build_options to accept GanttChartConfig

### Task 5.7: Update Sparkline implementation ✅
- **File**: `lib/ash_reports/charts/types/sparkline.ex`
- **Commit**: 938d941
- **Subtasks**:
  - [x] Change build/2 signature to accept SparklineConfig
  - [x] Map config.fill_colour and line_colour
  - [x] Update size mapping for compact defaults (100x20)
  - [x] Note: spot_radius, spot_colour, line_width not supported by Contex API

**Results**:
- ✅ All 7 chart type implementations updated (+225, -124 lines)
- ✅ Clean compilation with --warnings-as-errors
- ✅ Consistent pattern across all implementations
- ✅ Proper type-specific config struct usage
- ✅ All config fields mapped to Contex options
- ✅ No deprecated Contex function calls
- ✅ 7 atomic commits with clear messages
- ✅ 25% faster than estimated (1.5hrs vs 2-3hrs)

---

## Section 6: Update Renderers ✅ COMPLETE

**Duration**: 3-4 hours (Actual: 1 hour)
**Completed**: 2025-10-31
**Branch**: `feature/renderer-updates`
**Summary**: `notes/features/section6-renderer-updates-summary.md`

**Goal**: Update renderers to look up standalone chart definitions and handle type-specific configs.

### Task 6.1: Add chart lookup to HeexRenderer ✅
- **Files**: `lib/ash_reports/info.ex`, `lib/ash_reports/renderers/heex_renderer/band_renderer.ex`
- **Commit**: 6fbedfb
- **Subtasks**:
  - [x] Add charts/1, chart/2 functions to AshReports.Info
  - [x] Add resolve_chart_definition/2 function
  - [x] Lookup chart definition from domain via AshReports.Info
  - [x] Handle BarChart, LineChart, PieChart, AreaChart, ScatterChart, GanttChart, Sparkline
  - [x] Evaluate data_source expression with context
  - [x] Pass type-specific config to chart generation

### Task 6.2: Update chart element rendering in HeexRenderer ✅
- **File**: `lib/ash_reports/renderers/heex_renderer/band_renderer.ex`
- **Commit**: 6fbedfb
- **Subtasks**:
  - [x] Add render_element for BarChartElement
  - [x] Add render_element for LineChartElement
  - [x] Add render_element for PieChartElement
  - [x] Add render_element for AreaChartElement
  - [x] Add render_element for ScatterChartElement
  - [x] Add render_element for GanttChartElement
  - [x] Add render_element for SparklineElement
  - [x] Implement render_chart_element/3 with chart lookup
  - [x] Add get_chart_type_module/1 and get_config_module/1 mappings

### Task 6.3: Add chart lookup to ChartPreprocessor ✅
- **File**: `lib/ash_reports/typst/chart_preprocessor.ex`
- **Commit**: 615b1b0
- **Subtasks**:
  - [x] Add resolve_chart_definition/2 function
  - [x] Lookup chart from domain via AshReports.Info
  - [x] Handle type-specific chart structs
  - [x] Update extract_chart_elements for type-specific elements
  - [x] Add recursive band extraction
  - [x] Add is_chart_element?/1 guards for all 7 types

### Task 6.4: Update chart preprocessing in ChartPreprocessor ✅
- **File**: `lib/ash_reports/typst/chart_preprocessor.ex`
- **Commit**: 615b1b0
- **Subtasks**:
  - [x] Update process_chart/2 for type-specific chart elements
  - [x] Handle type-specific config structs from chart definitions
  - [x] Add generate_chart_svg/2 and build_chart_with_module/3
  - [x] Add get_chart_type_module/1 and get_config_module/1 mappings
  - [x] Remove old generic chart processing (evaluate_config/2)

**Results**:
- ✅ Both renderers updated (+384, -44 lines)
- ✅ Clean compilation with --warnings-as-errors
- ✅ Chart lookup via AshReports.Info module
- ✅ Type-specific config structs passed to chart implementations
- ✅ All 7 chart types supported in both renderers
- ✅ Consistent pattern between HeexRenderer and ChartPreprocessor
- ✅ 2 atomic commits with clear messages
- ✅ 75% faster than estimated (1hr vs 3-4hrs)

---

## Section 7: Chart Element Modules ✅ COMPLETE

**Duration**: 1-2 hours (Actual: Integrated into Section 4)
**Completed**: 2025-10-31
**Branch**: `feature/band-chart-elements`
**Summary**: Integrated with Section 4 - see `notes/features/section4-band-chart-elements-summary.md`

**Goal**: Create element module structs that reference standalone charts by name.

**Note**: This section was integrated into Section 4 implementation for efficiency. All element modules were created alongside the DSL entity definitions.

### Task 7.1: Create BarChartElement module ✅
- **File**: `lib/ash_reports/reports/element/bar_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with: name, chart_name, type, position, style, conditional
  - [x] Set type: :bar_chart_element
  - [x] Add @type spec
  - [x] Add moduledoc explaining chart reference
  - [x] Add new/2 constructor

### Task 7.2: Create LineChartElement module ✅
- **File**: `lib/ash_reports/reports/element/line_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :line_chart_element
  - [x] Add @type spec and moduledoc

### Task 7.3: Create PieChartElement module ✅
- **File**: `lib/ash_reports/reports/element/pie_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :pie_chart_element
  - [x] Add @type spec and moduledoc

### Task 7.4: Create AreaChartElement module ✅
- **File**: `lib/ash_reports/reports/element/area_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :area_chart_element
  - [x] Add @type spec and moduledoc

### Task 7.5: Create ScatterChartElement module ✅
- **File**: `lib/ash_reports/reports/element/scatter_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :scatter_chart_element
  - [x] Add @type spec and moduledoc

### Task 7.6: Create GanttChartElement module ✅
- **File**: `lib/ash_reports/reports/element/gantt_chart_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :gantt_chart_element
  - [x] Add @type spec and moduledoc

### Task 7.7: Create SparklineElement module ✅
- **File**: `lib/ash_reports/reports/element/sparkline_element.ex`
- **Commit**: d234e48
- **Subtasks**:
  - [x] Define defstruct with chart_name reference
  - [x] Set type: :sparkline_element
  - [x] Add @type spec and moduledoc

**Results**:
- ✅ All 7 element modules created (~75 lines each, 526 total)
- ✅ Consistent structure with defstruct, @type, new/2, process_options/1
- ✅ Comprehensive moduledocs with DSL examples
- ✅ Clean compilation with --warnings-as-errors
- ✅ Integrated into Section 4 commit (d234e48)

---

## Section 8: Delete Deprecated Code ✅

**Duration**: ~2 hours (estimated 30 minutes)

**Goal**: Remove all old generic chart code.

**Status**: Complete
**Completion Date**: 2025-10-31
**Branch**: `feature/delete-deprecated-charts`

### Task 8.1: Delete generic Config struct ✅
- **File to delete**: `lib/ash_reports/charts/config.ex`
- **Subtasks**:
  - [x] Delete the file completely
  - [x] Search codebase for AshReports.Charts.Config references
  - [x] Remove imports and aliases
- **Commit**: 43e2322 - "refactor: Delete generic Config struct and update references"
- **Files changed**: 4 files, 31 insertions(+), 251 deletions(-)

### Task 8.2: Delete generic Chart element ✅
- **File to delete**: `lib/ash_reports/reports/element/chart.ex`
- **Subtasks**:
  - [x] Delete the file completely
  - [x] Search codebase for AshReports.Element.Chart references
  - [x] Remove imports and aliases
  - [x] Update ChartDataCollector to use type-specific elements
  - [x] Enhanced all 7 chart types to accept both struct and map configs
  - [x] Fixed Contex compatibility (map to keyword list conversion)
- **Commit**: 218d309 - "refactor: Remove generic Chart element and update chart types"
- **Files changed**: 17 files, 193 insertions(+), 271 deletions(-)

### Task 8.3: Clean up chart_element_schema ✅
- **File**: `lib/ash_reports/dsl.ex`
- **Subtasks**:
  - [x] Delete chart_element_schema/0 function (already removed)
  - [x] Delete chart_element_entity/0 function (already removed)
- **Status**: Functions did not exist, already cleaned up in previous phases

**Summary**: Section 8 successfully removed 522 lines of deprecated code across 18 files. Enhanced chart type implementations now accept both typed structs and plain maps, with proper filtering and Contex compatibility. See `notes/features/section8_delete_deprecated_summary.md` for detailed implementation notes.

---

## Section 9: Update Tests

**Duration**: 4-5 hours

**Goal**: Create new tests for type-specific configs and update all existing tests.

### Task 9.1: Create config struct tests
- **Files to create**:
  - `test/ash_reports/charts/configs/bar_chart_config_test.exs`
  - `test/ash_reports/charts/configs/line_chart_config_test.exs`
  - `test/ash_reports/charts/configs/pie_chart_config_test.exs`
  - `test/ash_reports/charts/configs/area_chart_config_test.exs`
  - `test/ash_reports/charts/configs/scatter_chart_config_test.exs`
  - `test/ash_reports/charts/configs/gantt_chart_config_test.exs`
  - `test/ash_reports/charts/configs/sparkline_config_test.exs`
- **Subtasks** (for each):
  - [ ] Test struct creation with defaults
  - [ ] Test field validation
  - [ ] Test enum field validation (type, orientation, mode, etc.)
  - [ ] Test changeset validation

### Task 9.2: Update DSL tests
- **File**: `test/ash_reports/dsl_test.exs`
- **Subtasks**:
  - [ ] Add tests for standalone bar_chart definitions
  - [ ] Add tests for standalone line_chart definitions
  - [ ] Add tests for all 7 chart types
  - [ ] Test nested config sections parse correctly
  - [ ] Test chart references in band elements
  - [ ] Remove old generic chart element tests

### Task 9.3: Update chart type implementation tests
- **Files**: `test/ash_reports/charts/types/*_test.exs`
- **Subtasks**:
  - [ ] Update BarChart tests to use BarChartConfig
  - [ ] Update LineChart tests to use LineChartConfig
  - [ ] Update PieChart tests to use PieChartConfig
  - [ ] Update AreaChart tests to use AreaChartConfig
  - [ ] Update ScatterPlot tests to use ScatterChartConfig
  - [ ] Update GanttChart tests to use GanttChartConfig
  - [ ] Update Sparkline tests to use SparklineConfig

### Task 9.4: Update Charts module tests
- **File**: `test/ash_reports/charts/charts_test.exs`
- **Subtasks**:
  - [ ] Update generate/3 tests with type-specific configs
  - [ ] Remove generic Config tests
  - [ ] Verify all 7 chart types work with new configs

### Task 9.5: Update renderer tests
- **Files**:
  - `test/ash_reports/renderers/heex_renderer_test.exs`
  - `test/ash_reports/renderers/typst/*_test.exs`
- **Subtasks**:
  - [ ] Update tests to use standalone chart definitions
  - [ ] Test chart lookup by name
  - [ ] Test type-specific element rendering
  - [ ] Remove old generic chart rendering tests

### Task 9.6: Update integration tests
- **Files**: `test/ash_reports/integration/*_test.exs`
- **Subtasks**:
  - [ ] Update realistic test helpers to use new syntax
  - [ ] Update renderer integration tests
  - [ ] Verify end-to-end chart rendering works

---

## Section 10: Update Documentation

**Duration**: 2-3 hours

**Goal**: Completely rewrite chart documentation to reflect new DSL structure.

### Task 10.1: Rewrite graphs and visualizations guide
- **File**: `guides/user/graphs-and-visualizations.md`
- **Subtasks**:
  - [ ] Remove all old syntax examples
  - [ ] Add section: "Standalone Chart Definitions"
  - [ ] Add section: "Chart Types Overview"
  - [ ] Document bar_chart with all config options
  - [ ] Document line_chart with all config options
  - [ ] Document pie_chart with all config options
  - [ ] Document area_chart with all config options
  - [ ] Document scatter_chart with all config options
  - [ ] Document gantt_chart with DateTime requirements
  - [ ] Document sparkline with compact sizing
  - [ ] Add section: "Referencing Charts in Bands"
  - [ ] Add section: "Data Source Binding"
  - [ ] Add complete working examples

### Task 10.2: Update DSL moduledoc
- **File**: `lib/ash_reports/dsl.ex`
- **Subtasks**:
  - [ ] Update reports_section moduledoc with chart examples
  - [ ] Add example of standalone chart definition
  - [ ] Add example of chart reference in band
  - [ ] Remove old chart_type: :bar examples

### Task 10.3: Add moduledocs to config structs
- **Files**: `lib/ash_reports/charts/configs/*.ex`
- **Subtasks**:
  - [ ] Add comprehensive moduledoc to each config
  - [ ] Document each field with @doc
  - [ ] Add examples of DSL usage
  - [ ] Link to Contex documentation

### Task 10.4: Add moduledocs to chart definitions
- **Files**: `lib/ash_reports/charts/definitions/*.ex`
- **Subtasks**:
  - [ ] Add moduledoc with standalone definition example
  - [ ] Add moduledoc with band reference example
  - [ ] Document data source requirements
  - [ ] Document data format requirements

### Task 10.5: Add moduledocs to chart elements
- **Files**: `lib/ash_reports/reports/elements/*_chart_element.ex`
- **Subtasks**:
  - [ ] Document chart_name reference
  - [ ] Show example of element in band
  - [ ] Explain lookup behavior

### Task 10.6: Create migration guide
- **File**: `guides/migration/chart-dsl-refactor.md`
- **Subtasks**:
  - [ ] Document breaking changes
  - [ ] Show old syntax vs new syntax side-by-side
  - [ ] Provide step-by-step migration instructions
  - [ ] Add automated migration script (if feasible)

---

## Breaking Changes Summary

### Removed
1. **Generic chart element** - `chart :name do chart_type :bar ... end` no longer works
2. **AshReports.Charts.Config struct** - replaced with type-specific configs
3. **AshReports.Element.Chart module** - replaced with type-specific element modules
4. **chart_type field** - chart type now determined by section name

### Changed
1. **Chart location** - charts must be defined at top reports level, not inline in bands
2. **Chart reference** - bands reference charts by name using type-specific elements
3. **Config syntax** - config is now a nested section, not a flat map

### Migration Example

**Old Syntax:**
```elixir
band :detail do
  elements do
    chart :my_chart do
      chart_type :bar
      data_source expr(region_sales)
      config %{width: 600, type: :grouped}
    end
  end
end
```

**New Syntax:**
```elixir
# Define at top level
bar_chart :my_chart do
  data_source expr(region_sales)
  config do
    width 600
    type :grouped
  end
end

# Reference in band
band :detail do
  elements do
    bar_chart :my_chart
  end
end
```

---

## Success Criteria

- [ ] All 7 chart types have type-specific config structs with Contex-validated fields
- [ ] Charts can be defined at top reports level as standalone entities
- [ ] Charts can be referenced by name in band elements using type-specific syntax
- [ ] Config options are fully documented and validated
- [ ] Old generic Config struct is deleted
- [ ] Old generic chart element is deleted
- [ ] All tests updated and passing (target: 200+ tests)
- [ ] Documentation completely rewritten
- [ ] Migration guide provided

---

## Estimated Timeline

- **Section 1**: 2-3 hours (Config structs)
- **Section 2**: 2-3 hours (Chart definitions)
- **Section 3**: 4-5 hours (DSL entities)
- **Section 4**: 3-4 hours (Band elements)
- **Section 5**: 2-3 hours (Type implementations)
- **Section 6**: 3-4 hours (Renderers)
- **Section 7**: 1-2 hours (Element modules)
- **Section 8**: 30 minutes (Cleanup)
- **Section 9**: 4-5 hours (Tests)
- **Section 10**: 2-3 hours (Documentation)

**Total: 24-32 hours**

---

## Next Steps

1. Create feature branch: `feature/type-specific-chart-dsl`
2. Execute sections 1-10 in order
3. Commit after each section for reviewability
4. Run test suite after sections 5, 6, and 9
5. Final review and documentation check
6. Create PR with breaking change warnings
