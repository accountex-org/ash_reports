# Stage 3, Section 3.2.3: Dynamic Chart Configuration

**Status**: Planning
**Dependencies**: Section 3.1 (Chart Infrastructure), Section 3.2.1 (Data Processing), Section 3.2.2 (Chart Types)
**Estimated Duration**: 4-5 days
**Date Created**: 2025-10-03

## Problem Statement

### Current Limitations

The current chart infrastructure (completed in Sections 3.1, 3.2.1, 3.2.2) has the following limitations:

1. **Static Configuration**: Charts use hardcoded configuration with limited runtime customization
2. **No DSL Integration**: Charts cannot be configured through the Report DSL (must be created programmatically)
3. **Limited Theming**: No centralized theming system - colors, fonts, and styles are per-chart
4. **No Conditional Rendering**: Charts cannot be shown/hidden based on data conditions
5. **Fixed Layouts**: No responsive sizing or layout adaptation based on data/context
6. **Basic Customization**: Limited legend, axis, and annotation capabilities

### Why This Matters

Reports need dynamic, data-driven chart configuration to:
- **Adapt to data**: Show/hide charts based on data availability or business rules
- **Maintain consistency**: Apply organization-wide themes across all charts
- **Provide flexibility**: Allow runtime configuration from Report DSL without code changes
- **Improve UX**: Support responsive sizing, annotations, and interactive legends
- **Enable reusability**: Define chart templates that can be reused across reports

### Use Cases

1. **Conditional Charts**: Only show sales trend chart if >3 months of data available
2. **Corporate Theming**: Apply brand colors, fonts, and styles to all charts in a report
3. **Responsive Sizing**: Adjust chart dimensions based on data volume or report format
4. **Dynamic Annotations**: Add data labels for top 5 performers, highlight outliers
5. **Custom Legends**: Position legends based on chart complexity, show/hide series

## Solution Overview

### Approach

Implement a multi-layered configuration system that separates concerns:

1. **Config Schema Extensions** - Extend `AshReports.Charts.Config` with advanced options
2. **DSL Integration** - Add `chart` element type to Report DSL for declarative configuration
3. **Theming System** - Create centralized theme definitions with cascading overrides
4. **Conditional Rendering** - Implement data-driven chart visibility and configuration
5. **Runtime Evaluation** - Support dynamic configuration from report context/variables

### Architecture

```
Report DSL Definition
    ↓
chart element with config attributes
    ↓
DSLGenerator parses chart config → ChartConfig.from_dsl/2
    ↓
ChartConfig.apply_theme/2 → merge theme + overrides
    ↓
ChartConfig.evaluate_conditionals/2 → check visibility
    ↓
Charts.generate/3 → render with final config
    ↓
SVG output embedded in Typst
```

### Key Components

1. **Extended Config Schema** (`lib/ash_reports/charts/config.ex`)
   - Add theming fields (theme_name, custom_theme)
   - Add layout options (responsive, aspect_ratio, margins)
   - Add legend customization (position, orientation, custom_labels)
   - Add axis customization (tick_format, grid_style, label_rotation)
   - Add annotation support (data_labels, markers, reference_lines)

2. **Theme System** (`lib/ash_reports/charts/theme.ex`)
   - Define theme schema (colors, fonts, dimensions, styles)
   - Built-in themes: :default, :corporate, :minimal, :vibrant
   - Theme registry for custom themes
   - Theme inheritance and merging

3. **DSL Chart Element** (`lib/ash_reports/element/chart.ex`)
   - New element type: `:chart`
   - Chart-specific attributes (chart_type, data_source, config)
   - Conditional rendering support
   - Data binding from report query

4. **Config Builder** (`lib/ash_reports/charts/config_builder.ex`)
   - Parse chart element from DSL
   - Merge theme + overrides
   - Evaluate conditional config
   - Build final Config struct

5. **Conditional Renderer** (`lib/ash_reports/charts/conditional.ex`)
   - Evaluate visibility conditions
   - Evaluate dynamic config values
   - Support report variables/parameters in conditions

## Technical Details

### 1. Config Schema Extensions

**File**: `lib/ash_reports/charts/config.ex`

Add new fields to the embedded schema:

```elixir
embedded_schema do
  # Existing fields
  field :title, :string
  field :width, :integer, default: 600
  field :height, :integer, default: 400
  field :colors, {:array, :string}, default: []
  field :show_legend, :boolean, default: true
  field :legend_position, Ecto.Enum, values: [:top, :bottom, :left, :right], default: :right
  field :x_axis_label, :string
  field :y_axis_label, :string
  field :show_grid, :boolean, default: true
  field :font_family, :string, default: "sans-serif"
  field :font_size, :integer, default: 12

  # NEW: Theming
  field :theme_name, :string  # Reference to predefined theme
  field :theme, :map, default: %{}  # Embedded theme overrides

  # NEW: Layout and Sizing
  field :responsive, :boolean, default: false  # Adjust size based on data
  field :aspect_ratio, :float  # Width/height ratio (overrides height if set)
  field :margins, :map, default: %{top: 10, right: 10, bottom: 10, left: 10}
  field :padding, :map, default: %{top: 5, right: 5, bottom: 5, left: 5}

  # NEW: Legend Customization
  field :legend_orientation, Ecto.Enum, values: [:vertical, :horizontal], default: :vertical
  field :legend_font_size, :integer  # Override font_size for legend
  field :legend_labels, {:array, :string}  # Custom legend labels

  # NEW: Axis Customization
  field :x_axis_tick_format, :string  # Format string for x-axis ticks
  field :y_axis_tick_format, :string  # Format string for y-axis ticks
  field :x_axis_label_rotation, :integer, default: 0  # Degrees
  field :grid_color, :string  # Grid line color
  field :grid_stroke_width, :integer, default: 1

  # NEW: Data Labels and Annotations
  field :show_data_labels, :boolean, default: false
  field :data_label_position, Ecto.Enum,
    values: [:top, :center, :bottom, :auto], default: :auto
  field :data_label_format, :string  # Format string for data labels
  field :annotations, {:array, :map}, default: []  # Reference lines, markers, text

  # NEW: Conditional Rendering
  field :visible_condition, :string  # Expression to evaluate visibility
  field :min_data_points, :integer  # Minimum data points required
end
```

**Validation Updates**:
- Validate aspect_ratio > 0
- Validate theme_name exists in registry
- Validate annotation structure
- Validate tick_format strings

### 2. Theme System

**File**: `lib/ash_reports/charts/theme.ex`

```elixir
defmodule AshReports.Charts.Theme do
  @moduledoc """
  Chart theming system with predefined and custom themes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :colors, {:array, :string}
    field :font_family, :string
    field :font_size, :integer
    field :title_font_size, :integer
    field :background_color, :string
    field :grid_color, :string
    field :axis_color, :string
    field :legend_position, Ecto.Enum, values: [:top, :bottom, :left, :right]
    field :dimensions, :map  # {width: int, height: int}
  end

  @doc "Get predefined theme by name"
  def get(theme_name)

  @doc "Register custom theme"
  def register(name, theme_def)

  @doc "Apply theme to config, with config overrides taking precedence"
  def apply(config, theme_name)

  @doc "Merge two themes (second overrides first)"
  def merge(base_theme, override_theme)

  # Predefined themes
  def default_theme()
  def corporate_theme()
  def minimal_theme()
  def vibrant_theme()
end
```

**Built-in Themes**:

1. **:default** - Current default styling (already in Config.default_colors/0)
2. **:corporate** - Professional, muted colors, larger fonts
3. **:minimal** - Grayscale, clean, no grid
4. **:vibrant** - High-contrast, bold colors, thick strokes

**Theme Registry**:
- GenServer-based registry (similar to Chart.Registry)
- ETS table for fast lookups
- Allow runtime theme registration

### 3. DSL Chart Element

**File**: `lib/ash_reports/element/chart.ex`

```elixir
defmodule AshReports.Element.Chart do
  @moduledoc """
  Chart element for embedding visualizations in reports.
  """

  defstruct [
    :name,
    :chart_type,      # :bar, :line, :pie, :area, :scatter
    :data_source,     # Field or expression to get data
    :config,          # Chart configuration (merged with theme)
    :position,
    :style,
    :conditional,
    type: :chart
  ]

  @type t :: %__MODULE__{
    name: atom(),
    type: :chart,
    chart_type: atom(),
    data_source: Ash.Expr.t() | atom() | {:aggregated, map()},
    config: map(),  # Chart config options
    position: AshReports.Element.position(),
    style: AshReports.Element.style(),
    conditional: Ash.Expr.t() | nil
  }

  def new(name, opts \\ [])
end
```

**DSL Syntax Example**:

```elixir
report :sales_dashboard do
  bands do
    band :header do
      elements do
        chart :monthly_sales do
          chart_type :bar
          data_source expr(monthly_aggregates)

          config do
            theme :corporate
            title "Monthly Sales Trend"
            width 800
            height 400
            x_axis_label "Month"
            y_axis_label "Revenue ($)"
            show_data_labels true
            visible_condition expr(count(monthly_aggregates) >= 3)
          end

          position do
            x 0
            y 100
            width 800
            height 400
          end
        end
      end
    end
  end
end
```

### 4. Config Builder

**File**: `lib/ash_reports/charts/config_builder.ex`

```elixir
defmodule AshReports.Charts.ConfigBuilder do
  @moduledoc """
  Builds chart configuration from DSL definitions with theme support.
  """

  alias AshReports.Charts.{Config, Theme}
  alias AshReports.Element.Chart

  @doc """
  Build config from chart element with theme application.

  ## Steps
  1. Parse chart element config map
  2. Load theme if specified
  3. Merge: theme defaults → theme overrides → element config
  4. Validate final config
  5. Return Config struct
  """
  @spec from_element(Chart.t(), keyword()) :: {:ok, Config.t()} | {:error, term()}
  def from_element(%Chart{config: config_map}, opts \\ [])

  @doc """
  Evaluate dynamic config values from report context.

  Supports:
  - Report variables: ${variable_name}
  - Report parameters: ${param:param_name}
  - Data aggregates: expr(count(records))
  """
  @spec evaluate_dynamic(Config.t(), map()) :: Config.t()
  def evaluate_dynamic(config, context)

  @doc """
  Apply responsive sizing based on data volume.

  Adjusts width/height based on:
  - Number of data points
  - Number of series
  - Chart type
  """
  @spec apply_responsive_sizing(Config.t(), list()) :: Config.t()
  def apply_responsive_sizing(config, data)
end
```

### 5. Conditional Rendering

**File**: `lib/ash_reports/charts/conditional.ex`

```elixir
defmodule AshReports.Charts.Conditional do
  @moduledoc """
  Evaluates conditional chart visibility and dynamic configuration.
  """

  alias AshReports.Charts.Config

  @doc """
  Check if chart should be visible based on conditions.

  Conditions:
  - visible_condition: Ash expression (expr(...))
  - min_data_points: Minimum data points required
  - Element conditional: Standard element visibility
  """
  @spec visible?(Config.t(), map(), list()) :: boolean()
  def visible?(config, context, data)

  @doc """
  Evaluate config expression (for dynamic values).

  Example: title: "Sales Report - ${param:year}"
  """
  @spec eval_expr(String.t(), map()) :: term()
  def eval_expr(expr_string, context)

  @doc """
  Extract data requirements from config.

  Returns required data fields, aggregations, filters.
  """
  @spec data_requirements(Config.t()) :: keyword()
  def data_requirements(config)
end
```

## Implementation Plan

### Phase 1: Config Schema Extensions (Day 1)

**Tasks**:
1. Extend Config embedded schema with new fields
2. Update changeset validation for new fields
3. Add default values and validation rules
4. Update Config.new/1 to handle new fields
5. Write unit tests for extended validation

**Files Modified**:
- `lib/ash_reports/charts/config.ex` (~100 lines added)

**Tests**:
- Validate new fields (theme_name, responsive, margins, etc.)
- Test annotation structure validation
- Test aspect_ratio calculation
- Test custom legend labels

**Acceptance Criteria**:
- All new fields validated correctly
- Backward compatible with existing code
- 100% test coverage on new validations

### Phase 2: Theme System (Day 2)

**Tasks**:
1. Create Theme module with embedded schema
2. Implement built-in themes (default, corporate, minimal, vibrant)
3. Create ThemeRegistry GenServer
4. Implement Theme.apply/2 for merging themes with config
5. Write theme validation and merging logic
6. Add tests for theme system

**Files Created**:
- `lib/ash_reports/charts/theme.ex` (~250 lines)
- `lib/ash_reports/charts/theme_registry.ex` (~150 lines)

**Tests**:
- Test each built-in theme
- Test theme merging logic
- Test theme registry registration/lookup
- Test theme override behavior

**Acceptance Criteria**:
- 4 built-in themes working
- Theme registry supports custom themes
- Theme merging preserves config overrides
- All tests passing

### Phase 3: Chart Element and DSL Integration (Day 3)

**Tasks**:
1. Create Chart element module
2. Add chart element to DSL (extend elements section)
3. Update DSLGenerator to handle chart elements
4. Implement chart positioning in Typst templates
5. Write tests for chart element parsing

**Files Created**:
- `lib/ash_reports/element/chart.ex` (~80 lines)

**Files Modified**:
- DSL element definitions (add chart element type)
- `lib/ash_reports/typst/dsl_generator.ex` (add chart rendering)

**Tests**:
- Test chart element creation
- Test DSL parsing of chart elements
- Test chart element validation
- Test Typst generation with charts

**Acceptance Criteria**:
- Chart element in DSL parses correctly
- DSLGenerator produces valid Typst with SVG embedding
- Tests cover all chart types and configurations

### Phase 4: Config Builder (Day 4)

**Tasks**:
1. Create ConfigBuilder module
2. Implement from_element/2 for DSL → Config conversion
3. Implement evaluate_dynamic/2 for runtime evaluation
4. Implement apply_responsive_sizing/2
5. Add support for theme application
6. Write comprehensive tests

**Files Created**:
- `lib/ash_reports/charts/config_builder.ex` (~200 lines)

**Tests**:
- Test DSL config parsing
- Test theme application and merging
- Test dynamic value evaluation
- Test responsive sizing calculations

**Acceptance Criteria**:
- Config built correctly from DSL elements
- Themes applied and merged properly
- Dynamic values evaluated from context
- Responsive sizing works for all chart types

### Phase 5: Conditional Rendering (Day 5)

**Tasks**:
1. Create Conditional module
2. Implement visible?/3 for visibility evaluation
3. Implement eval_expr/2 for expression evaluation
4. Integrate with chart generation pipeline
5. Add support for min_data_points condition
6. Write tests for all conditions

**Files Created**:
- `lib/ash_reports/charts/conditional.ex` (~150 lines)

**Files Modified**:
- `lib/ash_reports/charts/charts.ex` (add visibility check)
- `lib/ash_reports/typst/dsl_generator.ex` (conditional chart rendering)

**Tests**:
- Test visibility conditions
- Test expression evaluation
- Test min_data_points filtering
- Test integration with Charts.generate/3

**Acceptance Criteria**:
- Charts respect visibility conditions
- Dynamic expressions evaluated correctly
- Charts hidden when conditions not met
- Tests cover all condition types

## Testing Strategy

### Unit Tests

**Config Module** (`test/ash_reports/charts/config_test.exs`):
- Validate all new fields
- Test annotation structure validation
- Test aspect_ratio behavior
- Test margins/padding validation
- Test backward compatibility

**Theme Module** (`test/ash_reports/charts/theme_test.exs`):
- Test built-in themes
- Test theme merging
- Test theme registry
- Test apply/2 with overrides

**Chart Element** (`test/ash_reports/element/chart_test.exs`):
- Test element creation
- Test validation
- Test DSL parsing

**ConfigBuilder** (`test/ash_reports/charts/config_builder_test.exs`):
- Test from_element/2
- Test theme application
- Test dynamic evaluation
- Test responsive sizing

**Conditional** (`test/ash_reports/charts/conditional_test.exs`):
- Test visible?/3
- Test eval_expr/2
- Test min_data_points
- Test data requirements extraction

### Integration Tests

**End-to-End Chart Generation** (`test/ash_reports/charts/integration_test.exs`):
- Test full pipeline: DSL → Config → Theme → Generate
- Test conditional rendering in reports
- Test responsive sizing with real data
- Test all chart types with themes

**DSL Generator** (`test/ash_reports/typst/dsl_generator_test.exs`):
- Test chart element in DSL generates correct Typst
- Test SVG embedding
- Test conditional chart rendering

### Performance Tests

**Theme Performance** (`test/ash_reports/charts/theme_performance_test.exs`):
- Benchmark theme application (target: <1ms)
- Benchmark config merging (target: <1ms)
- Test theme registry lookup speed

**Responsive Sizing** (`test/ash_reports/charts/responsive_performance_test.exs`):
- Benchmark sizing calculation (target: <1ms)
- Test with large datasets (1K, 10K, 100K points)

## Success Criteria

### Functional Requirements

1. **Config Extensions** ✓
   - All new fields validated and working
   - Backward compatible with existing code
   - Annotation structure supports reference lines, markers, text

2. **Theme System** ✓
   - 4 built-in themes available
   - Custom theme registration works
   - Theme merging respects config overrides
   - Theme registry supports concurrent access

3. **DSL Integration** ✓
   - Chart element in DSL parses correctly
   - Charts embedded in Typst templates
   - Supports all chart types
   - Data binding from report query works

4. **Dynamic Configuration** ✓
   - Runtime config evaluation from variables/parameters
   - Responsive sizing adjusts to data volume
   - Theme application at runtime
   - Config merging: theme → element config → runtime overrides

5. **Conditional Rendering** ✓
   - Charts respect visibility conditions
   - min_data_points filtering works
   - Expression evaluation from report context
   - Charts hidden when conditions not met

### Non-Functional Requirements

1. **Performance**
   - Config building: <5ms per chart
   - Theme application: <1ms per chart
   - Responsive sizing calculation: <1ms
   - No performance regression on existing charts

2. **Maintainability**
   - Clean separation: Config → Theme → Builder → Conditional
   - Well-documented modules and functions
   - Consistent error handling
   - Comprehensive test coverage (>90%)

3. **Usability**
   - Intuitive DSL syntax for chart configuration
   - Helpful error messages for invalid config
   - Theme system easy to extend
   - Good examples in documentation

## Open Questions

1. **Contex Customization Limitations**
   - How much customization does Contex support for legends/axes?
   - May need SVG post-processing for advanced features
   - Should we document Contex limitations upfront?

2. **Expression Evaluation**
   - Should we use Ash.Expr evaluation or custom expression parser?
   - How to handle complex expressions (nested, multi-variable)?
   - Performance implications of expression evaluation?

3. **Responsive Sizing Algorithm**
   - What formula for calculating optimal chart size?
   - Different formulas per chart type?
   - Max/min dimensions to prevent extreme sizes?

4. **Annotation Format**
   - What structure for annotations? (reference_lines, markers, text_boxes)
   - How to specify positioning (relative vs absolute)?
   - Support for dynamic annotation values?

## Future Enhancements (Not in Scope)

1. **Advanced Theming**
   - CSS-like theme inheritance
   - Theme variables (e.g., $primary-color)
   - Theme variants (light/dark mode)

2. **Interactive Charts**
   - Click handlers for drill-down
   - Hover tooltips
   - Zoom/pan controls
   - Requires LiveView integration (Stage 4)

3. **Custom SVG Post-Processing**
   - Advanced annotation rendering
   - Custom legend layouts
   - Gradient fills
   - Pattern fills

4. **Data-Driven Themes**
   - Auto-generate theme from data characteristics
   - Accessibility-focused themes (colorblind-safe)
   - Print-optimized themes

5. **Chart Templates**
   - Reusable chart configurations
   - Chart template library
   - Template inheritance

## Dependencies

### Internal Dependencies
- **Section 3.1**: Chart Infrastructure (Registry, Renderer, Cache)
- **Section 3.2.1**: Data Processing (DataExtractor, Aggregator, TimeSeries)
- **Section 3.2.2**: Chart Types (Bar, Line, Pie, Area, Scatter)

### External Dependencies
- **Contex 0.5.0**: Chart rendering library
- **Ecto**: Embedded schema for Config and Theme
- **Ash Framework**: Expression evaluation (Ash.Expr)

## Migration Path

### Backward Compatibility

All existing code remains compatible:
- Current Config usage works without changes
- New fields have sensible defaults
- Theme system is opt-in (defaults to current behavior)

### Upgrade Path

1. **Immediate**: New code can use extended config
2. **Phase 1**: Add themes to existing chart generation
3. **Phase 2**: Migrate programmatic charts to DSL
4. **Phase 3**: Apply corporate theme to all reports

## Documentation Updates

### New Documentation

1. **Chart Theming Guide** - How to create and use themes
2. **Chart DSL Reference** - Syntax for chart elements
3. **Dynamic Configuration Guide** - Using variables/parameters in charts
4. **Conditional Rendering Guide** - Visibility rules and data requirements

### Updated Documentation

1. **Charts.Config** - Document new fields
2. **Report DSL** - Add chart element syntax
3. **Chart Examples** - Show themed, responsive, conditional charts

## Risks and Mitigations

### Risk 1: Contex Limitations
- **Risk**: Contex may not support all desired customizations
- **Mitigation**: Document limitations, implement SVG post-processing fallback
- **Impact**: Medium - May require workarounds for advanced features

### Risk 2: Performance Overhead
- **Risk**: Theme merging and dynamic evaluation add overhead
- **Mitigation**: Benchmark early, cache theme application results
- **Impact**: Low - Config building is one-time per chart

### Risk 3: DSL Complexity
- **Risk**: Chart DSL may become too complex with all options
- **Mitigation**: Use sensible defaults, provide presets, good examples
- **Impact**: Low - Optional features, defaults work for most cases

### Risk 4: Expression Evaluation Security
- **Risk**: Dynamic expression evaluation could expose security issues
- **Mitigation**: Use Ash.Expr (already sandboxed), validate inputs
- **Impact**: Low - Ash.Expr is battle-tested

## Timeline

- **Day 1**: Config Schema Extensions
- **Day 2**: Theme System
- **Day 3**: Chart Element and DSL Integration
- **Day 4**: Config Builder
- **Day 5**: Conditional Rendering and Integration Testing

**Total**: 4-5 days

## Completion Checklist

### Implementation
- [ ] Config schema extended with new fields
- [ ] Theme module and registry implemented
- [ ] Chart element created and integrated
- [ ] ConfigBuilder module implemented
- [ ] Conditional rendering module implemented
- [ ] All modules integrated into chart generation pipeline

### Testing
- [ ] Unit tests for Config extensions (>90% coverage)
- [ ] Unit tests for Theme system (>90% coverage)
- [ ] Unit tests for Chart element (>90% coverage)
- [ ] Unit tests for ConfigBuilder (>90% coverage)
- [ ] Unit tests for Conditional (>90% coverage)
- [ ] Integration tests for full pipeline
- [ ] Performance benchmarks passing

### Documentation
- [ ] Chart theming guide written
- [ ] Chart DSL reference updated
- [ ] Dynamic configuration guide written
- [ ] Conditional rendering guide written
- [ ] Code documentation complete
- [ ] Examples added to guides

### Quality
- [ ] All tests passing
- [ ] No performance regressions
- [ ] Code review completed
- [ ] Documentation reviewed
- [ ] Backward compatibility verified
