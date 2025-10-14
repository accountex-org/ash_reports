# Stage 2, Section 2.4.2: HEEX Renderer and LiveView Tests - Feature Plan

**Feature Branch:** `feature/stage2-4-2-heex-renderer-tests`
**Estimated Duration:** 2 days (12-16 hours)
**Dependencies:** Section 2.4.1 (HTML Renderer Core Tests) - ✅ Complete
**Status:** Planning Phase

## 1. Problem Statement

### Current State

The HEEX renderer and LiveView integration modules provide comprehensive Phoenix.Component-based rendering with real-time capabilities, but test coverage is incomplete:

**Untested Modules (0% coverage):**
- `heex_renderer.ex` - Core HEEX rendering with Phase 6.2 chart integration
- `heex_renderer_enhanced.ex` - Enhanced LiveView chart component integration
- `template_optimizer.ex` - Template optimization and caching system
- `chart_templates.ex` - Reusable HEEX chart templates

**Partially Tested (tests exist but need fixes/expansion):**
- `helpers.ex` - HEEX template helpers (test exists: 17,277 bytes)
- `components.ex` - Phoenix component library (test exists: 11,753 bytes)
- `live_view_integration.ex` - LiveView helpers (test exists: 15,858 bytes)

**Main Test Suite:**
- `heex_renderer_test.exs` - Exists with 421 lines covering basic functionality

### Test Coverage Gaps

1. **HEEX Renderer Core** (`heex_renderer.ex` - 719 lines)
   - Chart component integration (Phase 6.2)
   - Context preparation and validation
   - Component assigns building
   - Template generation with charts
   - LiveView-specific rendering
   - Performance optimization features
   - Error handling paths

2. **HEEX Renderer Enhanced** (`heex_renderer_enhanced.ex` - 379 lines)
   - Enhanced LiveView chart integration
   - Real-time chart updates
   - Dashboard component generation
   - LiveView mount/handle_info generation
   - Chart component HEEX generation
   - Asset integration

3. **Template Optimizer** (`template_optimizer.ex` - 107 lines)
   - Template optimization algorithms
   - Whitespace removal
   - Static section caching
   - Template compression
   - ETS cache operations
   - Cache key generation

4. **Chart Templates** (`chart_templates.ex` - 543 lines)
   - Single chart template generation
   - Dashboard grid layouts
   - Filter dashboard templates
   - Real-time dashboard templates
   - Tabbed charts interface
   - Filter control generation
   - Localization (4 languages: en, ar, es, fr)

5. **Helpers Module** (`helpers.ex` - 655 lines) - Needs Test Fixes
   - Layout helpers (element/band/report classes)
   - Style generation (inline CSS)
   - Format helpers (currency, percentage, date/time, numbers)
   - Utility helpers (field access, visibility, accessibility)
   - Element type detection
   - CSS class building

6. **Components Module** (`components.ex` - 788 lines) - Needs Test Expansion
   - Container components (report_container, header, content, footer)
   - Band components (band_group, band)
   - Element components (label, field, image, line, box, aggregate, expression)
   - Component rendering pipeline
   - Style/class generation
   - Value formatting

7. **LiveView Integration** (`live_view_integration.ex` - 595 lines) - Needs Test Fixes
   - PubSub subscriptions
   - Event handling (filter, sort, pagination)
   - Data streaming
   - Real-time updates
   - Filter/sort/pagination logic
   - Atom validation for security
   - Socket manipulation helpers

## 2. Solution Overview

### Testing Strategy

**Phase 1: Fix Existing Tests** (4-6 hours)
- Fix helpers_test.exs compilation issues
- Fix components_test.exs API mismatches
- Fix live_view_integration_test.exs private function access
- Update existing heex_renderer_test.exs for new features

**Phase 2: Test Untested Modules** (6-8 hours)
- Create comprehensive tests for heex_renderer.ex (Phase 6.2 charts)
- Create tests for heex_renderer_enhanced.ex
- Create tests for template_optimizer.ex
- Create tests for chart_templates.ex

**Phase 3: Expand Partial Coverage** (2-4 hours)
- Expand helpers tests for all formatting functions
- Expand components tests for all component types
- Expand LiveView integration tests for streaming/real-time

### Test Infrastructure

**Shared Test Helpers** (existing):
- `test/support/renderer_test_helpers.ex` - Already has RenderContext builders
- `test/support/live_view_test_helpers.ex` - Likely exists for LiveView mocking

**New Test Helpers Needed:**
- Chart configuration builders
- Dashboard configuration builders
- Socket mock builders (may already exist)
- Template comparison utilities

## 3. Module Analysis

### 3.1 HeexRenderer (`heex_renderer.ex` - 719 lines)

#### Current Functionality

**Core Interface (Renderer Behavior):**
- `render_with_context/2` - Main rendering entry point with Phase 6.2 chart integration
- `supports_streaming?/0` - Returns true for LiveView streaming
- `file_extension/0` - Returns "heex"
- `content_type/0` - Returns "text/heex"
- `validate_context/1` - Validates report, records, Phoenix.Component availability
- `prepare/2` - Enhances context with HEEX configuration and state
- `cleanup/2` - Cleans up component cache and PubSub subscriptions
- `render/3` - Legacy API for backward compatibility

**HEEX-Specific Functions:**
- `render_for_liveview/2` - Returns assigns and template for LiveView embedding
- `render_component/3` - Renders individual component (header, band, element)

**Internal Pipeline:**
1. `prepare_heex_context/2` - Adds HEEX config to context
2. `prepare_chart_components/1` - Extracts and builds chart component data (Phase 6.2)
3. `build_component_assigns/2` - Creates assigns map with chart support
4. `generate_enhanced_heex_template/3` - Generates template with charts
5. `build_enhanced_result_metadata/2` - Builds metadata with chart info

**Chart Integration (Phase 6.2):**
- `extract_chart_configs_from_context/1` - Gets chart configs from metadata
- `build_chart_component_data/3` - Builds chart component structure
- `generate_base_report_template/2` - Base HEEX template
- `generate_chart_components_heex/2` - Chart section HEEX
- `generate_single_chart_component_heex/2` - Individual chart component
- `integrate_charts_into_template/3` - Merges charts with base template

**Validation:**
- `validate_heex_requirements/1` - Checks report and records exist
- `validate_component_compatibility/1` - Ensures Phoenix.Component available
- `validate_liveview_support/1` - Checks LiveView availability if enabled

**Configuration:**
- `build_heex_config/2` - Creates config with 9 options:
  - component_style (:modern/:classic/:minimal)
  - liveview_enabled (boolean)
  - interactive (boolean)
  - real_time_updates (boolean)
  - enable_filters (boolean)
  - custom_components (map)
  - css_framework (:tailwind)
  - accessibility (boolean)
  - static_optimization (boolean)

**State Initialization:**
- `initialize_component_state/1` - Sets up component cache
- `initialize_liveview_state/1` - Sets up PubSub and event handlers
- `initialize_template_state/1` - Sets up template cache and optimization

#### Public API Functions (8 functions)

1. **`render_with_context/2`** - Main rendering with charts
   - Input: RenderContext, opts
   - Output: `{:ok, %{content:, metadata:, context:, assigns:}}` or error
   - Integrates Phase 6.2 chart components

2. **`supports_streaming?/0`** - Streaming capability
   - Output: true

3. **`file_extension/0`** - File extension
   - Output: "heex"

4. **`content_type/0`** - MIME type
   - Output: "text/heex"

5. **`validate_context/1`** - Context validation
   - Input: RenderContext
   - Output: :ok or {:error, reason}

6. **`prepare/2`** - Context preparation
   - Input: RenderContext, opts
   - Output: {:ok, enhanced_context}

7. **`cleanup/2`** - Resource cleanup
   - Input: RenderContext, result
   - Output: :ok

8. **`render/3`** - Legacy API
   - Input: report_module, data, opts
   - Output: {:ok, content} or error

9. **`render_for_liveview/2`** - LiveView embedding
   - Input: RenderContext, opts
   - Output: {:ok, assigns, template}

10. **`render_component/3`** - Single component
    - Input: RenderContext, component_type, opts
    - Output: {:ok, heex} or error

#### Test Scenarios Needed (70 tests)

**Basic Rendering (15 tests):**
- Renders basic report without charts
- Renders report with single chart
- Renders report with multiple charts
- Handles empty data
- Handles missing report
- Handles missing records
- Includes proper HEEX structure
- Includes component assigns
- Includes data attributes
- Generates proper metadata
- Measures render time
- Handles large datasets
- Applies static optimization
- Preserves locale settings
- Handles RTL text direction

**Chart Integration (15 tests):**
- Extracts chart configs from context
- Builds chart component data structures
- Generates chart HEEX templates
- Integrates charts into base template
- Handles multiple chart providers (Chart.js, D3, Plotly)
- Generates chart hooks JavaScript
- Includes chart CSS assets
- Handles interactive chart configuration
- Handles real-time chart configuration
- Handles missing chart configs (empty array)
- Validates chart configuration structure
- Generates unique chart IDs
- Preserves chart locale settings
- Handles chart metadata
- Integrates with AssetManager

**Component Rendering (10 tests):**
- Renders report_container component
- Renders report_header component
- Renders report_content component
- Renders report_footer component
- Renders band_group component
- Renders band component
- Renders element component
- Returns error for unknown component
- Renders component with custom config
- Renders component with assigns

**Context Validation (10 tests):**
- Validates complete valid context
- Rejects nil report
- Rejects empty records array
- Validates Phoenix.Component availability
- Validates LiveView when enabled
- Skips LiveView validation when disabled
- Handles missing config gracefully
- Validates chart configs structure
- Handles malformed context
- Provides descriptive error messages

**Context Preparation (10 tests):**
- Adds HEEX configuration
- Initializes component state
- Initializes LiveView state when enabled
- Initializes template state
- Merges custom components
- Sets up component cache
- Sets up PubSub subscriptions
- Sets up event handlers
- Handles preparation errors
- Preserves existing config

**LiveView Integration (10 tests):**
- Renders for LiveView embedding
- Returns proper assigns structure
- Returns valid HEEX template
- Includes LiveView-specific metadata
- Enables real-time updates
- Enables interactive features
- Handles filter configuration
- Handles streaming configuration
- Compatible with live_component
- Compatible with Phoenix.Component

#### Edge Cases to Cover (10 tests)

- Very large datasets (10,000+ records)
- Unicode in component text
- Special characters in chart data
- Nil values in assigns
- Missing optional config values
- Chart configs with invalid provider
- Template generation timeout
- Memory pressure during rendering
- Concurrent rendering calls
- Cleanup during active render

#### Success Criteria

- 70 tests total
- All public API functions tested
- All chart integration paths tested
- All validation scenarios covered
- Error handling verified
- Performance benchmarks established
- LiveView compatibility confirmed
- Memory usage within bounds

---

### 3.2 HeexRendererEnhanced (`heex_renderer_enhanced.ex` - 379 lines)

#### Current Functionality

**Core Interface:**
- Implements `AshReports.Renderer` behavior
- Builds on base HeexRenderer with enhanced chart capabilities
- Generates LiveView mount/handle_info functions

**Rendering Pipeline:**
1. `render_with_context/2` - Enhanced rendering with LiveView charts
2. `prepare_enhanced_context/1` - Adds LiveView metadata
3. `generate_liveview_chart_components/1` - Creates chart components
4. `render_base_heex_content/1` - Delegates to base HeexRenderer
5. `integrate_charts_with_heex/3` - Merges charts into template
6. `add_liveview_assets/2` - Adds hooks and CSS

**LiveView Code Generation:**
- `generate_liveview_mount/1` - Creates mount/3 function
- `generate_liveview_handle_info/0` - Creates handle_info/2 functions

**Chart Component Generation:**
- `generate_chart_component_heex/3` - Individual chart component
- Multiple chart providers supported

#### Public API Functions (6 functions)

1. **`render_with_context/2`** - Enhanced rendering
2. **`render/3`** - Legacy API
3. **`generate_liveview_mount/1`** - Mount function code
4. **`generate_liveview_handle_info/0`** - Handle info code
5. **`content_type/0`** - Returns "text/html"
6. **`file_extension/0`** - Returns "heex"
7. **`supports_streaming?/0`** - Returns true

#### Test Scenarios Needed (45 tests)

**Enhanced Rendering (10 tests):**
- Renders with LiveView chart components
- Integrates with base HEEX renderer
- Adds LiveView-specific metadata
- Generates proper hooks registration
- Includes chart CSS assets
- Handles multiple charts
- Preserves base template structure
- Adds real-time capabilities
- Handles missing chart configs
- Generates unique component IDs

**LiveView Code Generation (10 tests):**
- Generates valid mount/3 function
- Includes dashboard initialization
- Sets up PubSub subscriptions
- Configures real-time updates
- Generates handle_info for chart updates
- Generates handle_info for dashboard updates
- Generates handle_info for errors
- Handles missing dashboard config
- Preserves Elixir syntax
- Formats code properly

**Chart Component Generation (10 tests):**
- Generates single chart component
- Generates multiple chart components
- Includes proper chart_config attributes
- Sets interactive flag
- Sets real-time flag
- Assigns unique IDs
- Preserves locale settings
- Handles chart provider selection
- Includes update_interval for real-time
- Generates valid HEEX syntax

**Asset Integration (10 tests):**
- Adds chart CSS to template
- Adds hook registration JavaScript
- Uses AssetManager for links
- Inserts in proper location (head)
- Handles missing head tag
- Includes module type for JS
- Generates proper style tags
- Preserves existing assets
- Handles RTL layouts
- Minifies assets when configured

**Error Handling (5 tests):**
- Handles base renderer failure
- Handles invalid chart config
- Handles missing dependencies
- Provides descriptive errors
- Gracefully degrades without charts

#### Edge Cases

- Template without head/body tags
- Chart configs with missing required fields
- Invalid JavaScript in hooks
- CSS injection attempts
- Very long dashboard configurations

#### Success Criteria

- 45 tests total
- All rendering paths tested
- Code generation validated
- Asset integration verified
- Error handling comprehensive

---

### 3.3 TemplateOptimizer (`template_optimizer.ex` - 107 lines)

#### Current Functionality

**Core Functions:**
- `optimize_template/2` - Main optimization entry point
- `compile_and_cache/3` - Compile and store in ETS
- `clear_cache/0` - Clean ETS cache

**Optimization Steps:**
1. `remove_unnecessary_whitespace/1` - Minifies template
2. `optimize_static_sections/2` - Caches static parts
3. `compress_template_size/1` - Removes comments/empty attrs

**Caching:**
- Uses ETS table `:ash_reports_template_cache`
- `generate_cache_key/1` - MD5 hash with timestamp
- `store_in_cache/2` - ETS insert with table creation

#### Public API Functions (3 functions)

1. **`optimize_template/2`** - Optimize template string
   - Input: template_string, opts
   - Output: {:ok, optimized} or {:error, message}

2. **`compile_and_cache/3`** - Compile and cache
   - Input: template_name, template_string, opts
   - Output: :ok or {:error, message}

3. **`clear_cache/0`** - Clear ETS cache
   - Output: :ok

#### Test Scenarios Needed (35 tests)

**Optimization Functions (15 tests):**
- Removes excessive whitespace
- Preserves necessary whitespace in text
- Optimizes tag spacing
- Removes HTML comments
- Removes empty class attributes
- Removes empty style attributes
- Caches static sections when enabled
- Skips static caching when disabled
- Handles nested templates
- Preserves HEEX expressions
- Preserves Phoenix.Component syntax
- Handles empty template
- Handles very large template
- Measures optimization performance
- Returns error on invalid input

**Caching Operations (10 tests):**
- Creates ETS table on first use
- Reuses existing ETS table
- Generates unique cache keys
- Stores optimized template
- Retrieves cached template
- Handles cache key collisions
- Clears entire cache
- Handles missing cache table
- Handles concurrent access
- Measures cache performance

**Error Handling (5 tests):**
- Handles malformed template
- Handles nil template
- Handles optimization errors
- Provides descriptive errors
- Gracefully degrades on failure

**Cache Key Generation (5 tests):**
- Generates consistent keys for same input
- Generates unique keys for different inputs
- Includes timestamp in key
- Uses MD5 hash
- Truncates to 8 characters

#### Edge Cases

- Template with only whitespace
- Template with special regex characters
- Very large template (>1MB)
- Concurrent optimization calls
- ETS table deleted during operation
- Memory exhaustion

#### Success Criteria

- 35 tests total
- All optimization paths tested
- Cache operations verified
- Error handling complete
- Performance benchmarks established

---

### 3.4 ChartTemplates (`chart_templates.ex` - 543 lines)

#### Current Functionality

**Template Types:**
1. **Single Chart** - Simple chart with optional controls
2. **Dashboard Grid** - Multi-chart grid layout
3. **Filter Dashboard** - Chart with sidebar filters
4. **Real-time Dashboard** - Live updating charts with metrics
5. **Tabbed Charts** - Multiple charts in tabs

**Components:**
- Chart containers with headers
- Real-time indicators
- Filter controls (date_range, region, category, text_search)
- Performance metrics display
- Tab navigation

**Localization:**
- Supports 4 languages: English, Arabic, Spanish, French
- 25+ localized strings
- RTL layout support

#### Public API Functions (5 functions)

1. **`single_chart/2`** - Single chart template
   - Input: config, RenderContext
   - Output: HEEX string

2. **`dashboard_grid/2`** - Grid dashboard template
   - Input: config, RenderContext
   - Output: HEEX string

3. **`filter_dashboard/2`** - Filter dashboard template
   - Input: config, RenderContext
   - Output: HEEX string

4. **`realtime_dashboard/2`** - Real-time dashboard template
   - Input: config, RenderContext
   - Output: HEEX string

5. **`tabbed_charts/2`** - Tabbed interface template
   - Input: config, RenderContext
   - Output: HEEX string

#### Test Scenarios Needed (60 tests)

**Single Chart Template (12 tests):**
- Generates basic chart container
- Includes chart title
- Shows real-time indicator when enabled
- Hides indicator when disabled
- Includes chart controls when enabled
- Hides controls when disabled
- Applies RTL class correctly
- Includes live_component call
- Sets chart_id properly
- Preserves locale
- Handles missing title
- Handles missing config

**Dashboard Grid Template (12 tests):**
- Generates grid container
- Creates grid with specified columns
- Renders multiple charts
- Applies grid-column spans
- Shows dashboard header
- Includes real-time status
- Preserves chart order
- Handles empty charts array
- Applies RTL layout
- Sets dashboard ID
- Localizes dashboard title
- Handles custom grid columns

**Filter Dashboard Template (12 tests):**
- Generates dashboard with sidebar
- Positions sidebar left by default
- Positions sidebar right when specified
- Generates date_range filter
- Generates region filter
- Generates category filter
- Generates text_search filter
- Includes apply button
- Includes reset button
- Localizes filter labels
- Applies RTL to sidebar
- Handles empty filters array

**Real-time Dashboard Template (12 tests):**
- Shows connection status indicator
- Displays latency metric when enabled
- Displays updates count when enabled
- Shows last update timestamp
- Sets update interval
- Generates real-time chart components
- Applies RTL layout
- Localizes status text
- Handles missing metrics
- Updates status dynamically
- Includes performance metrics
- Preserves locale settings

**Tabbed Charts Template (12 tests):**
- Generates tab headers
- Generates tab contents
- Sets first tab as active
- Includes phx-click handlers
- Sets unique tab IDs
- Preserves tab order
- Includes chart config in tabs
- Applies active class correctly
- Handles empty tabs array
- Localizes tab titles
- Switches tabs on click
- Applies RTL to tabs

#### Localization Tests (25 tests)

**For each of 25 localized strings:**
- English translation correct
- Arabic translation correct
- Spanish translation correct
- French translation correct
- Fallback to English for unknown locale

**Localized strings to test:**
- Live/En vivo/مباشر/En direct
- Dashboard/Panel de control/لوحة التحكم/Tableau de bord
- Filters/Filtros/المرشحات/Filtres
- Apply/Aplicar/تطبيق/Appliquer
- Reset/Restablecer/إعادة تعيين/Réinitialiser
- Connected/Conectado/متصل/Connecté
- And 19 more...

#### Edge Cases

- Empty chart configuration
- Missing locale settings
- Very long chart titles
- Special characters in filter values
- Invalid sidebar position
- Nil context
- Missing chart IDs
- Update interval of 0
- Too many tabs (>20)
- RTL with complex layouts

#### Success Criteria

- 60 tests for templates
- 25 tests for localization (can be grouped)
- All template types covered
- All filter types tested
- All localization strings verified
- RTL rendering confirmed

---

### 3.5 Helpers (`helpers.ex` - 655 lines) - Fix Existing Tests

#### Current Functionality

**Layout Helpers (11 functions):**
- `element_classes/2` - CSS classes for elements
- `band_classes/2` - CSS classes for bands
- `report_classes/3` - CSS classes for reports
- `build_css_classes/1` - Join class list
- `element_styles/1` - Inline styles for elements
- `band_styles/1` - Inline styles for bands
- `build_style_string/1` - Join style declarations
- `element_id/1` - Generate unique element ID
- `band_id/1` - Generate unique band ID
- `responsive_classes/1` - Responsive CSS classes
- `accessibility_attrs/1` - ARIA attributes

**Format Helpers (6 functions):**
- `format_currency/2` - Format with symbol ($, €, etc.)
- `format_percentage/2` - Format with precision
- `format_date/2` - Format Date (short/medium/long)
- `format_datetime/2` - Format DateTime (short/medium/long)
- `format_number/2` - Format with thousands separator

**Utility Helpers (3 functions):**
- `get_field_value/3` - Safe field access with default
- `get_nested_field/3` - Safe nested access
- `element_visible?/3` - Visibility condition evaluation

#### Existing Test File Issues

**File:** `test/ash_reports/heex_renderer/helpers_test.exs` (17,277 bytes)

**Likely Issues to Fix:**
- Struct format mismatches (same as HTML renderer tests)
- Missing position/style fields in test data
- Incorrect expected CSS output
- Missing RenderContext setup
- Private function access attempts

#### Test Scenarios Needed (80 tests)

**CSS Class Generation (20 tests):**
- Generates element classes with type
- Includes positioning classes
- Includes sizing classes
- Adds custom classes
- Generates band classes with type
- Includes layout classes
- Includes height classes
- Generates report classes with theme
- Includes responsive classes
- Includes layout mode classes
- Builds class list correctly
- Filters nil values
- Filters empty strings
- Trims whitespace
- Handles empty list
- Handles nil input
- Handles mixed valid/invalid
- Applies modern theme
- Applies classic theme
- Applies minimal theme

**Inline Style Generation (15 tests):**
- Generates position styles (absolute)
- Generates dimension styles (width/height)
- Generates appearance styles (color, bg, font)
- Handles missing position
- Handles missing dimensions
- Handles missing style
- Builds style string correctly
- Joins with semicolons
- Adds trailing semicolon
- Filters nil values
- Filters empty strings
- Handles empty list
- Handles nil input
- Generates band height style
- Generates band background style

**Format Helpers - Currency (10 tests):**
- Formats with default $ symbol
- Formats with custom symbol (€, £)
- Adds thousands separators
- Preserves 2 decimal places
- Handles integer input
- Handles float input
- Handles zero
- Handles negative numbers
- Handles very large numbers
- Returns empty string for non-numbers

**Format Helpers - Percentage (5 tests):**
- Formats with default 2 decimals
- Formats with custom precision
- Multiplies by 100
- Adds % symbol
- Handles edge cases

**Format Helpers - Date/Time (15 tests):**
- Formats date with default format
- Formats date as short (MM/DD/YY)
- Formats date as medium (Mon DD, YYYY)
- Formats date as long (Month DD, YYYY)
- Formats datetime with default format
- Formats datetime as short
- Formats datetime as medium
- Formats datetime as long
- Handles Date struct
- Handles DateTime struct
- Handles nil date
- Handles nil datetime
- Converts DateTime to Date
- Preserves timezone in output
- Handles invalid date

**Format Helpers - Numbers (5 tests):**
- Formats integer with thousands separator
- Formats float with precision
- Handles zero
- Handles large numbers
- Returns empty string for invalid

**Utility Helpers (10 tests):**
- Gets field from map
- Returns default for missing field
- Returns default for nil record
- Gets nested field from path
- Handles nil in nested path
- Handles missing nested field
- Generates unique element ID
- Generates unique band ID
- Evaluates visibility condition
- Returns true for nil condition

#### Test Fixes Required

1. **Update test data structures** to match actual Element/Band structs
2. **Fix CSS output assertions** to match actual generated classes
3. **Add proper RenderContext** where needed
4. **Remove private function calls** or test through public API
5. **Update format expectations** to match current implementation

#### Success Criteria

- 80 tests total (may include fixing existing)
- All layout helpers tested
- All format helpers tested
- All utility helpers tested
- Edge cases covered
- Private functions tested indirectly

---

### 3.6 Components (`components.ex` - 788 lines) - Expand Existing Tests

#### Current Functionality

**Container Components (4 functions):**
- `report_container/1` - Main report wrapper with attrs
- `report_header/1` - Title, metadata, timestamp
- `report_content/1` - Content area wrapper
- `report_footer/1` - Footer with timestamp

**Band Components (2 functions):**
- `band_group/1` - Band collection manager
- `band/1` - Individual band renderer

**Element Components (7 functions):**
- `element/1` - Universal element dispatcher
- `label_element/1` - Static text
- `field_element/1` - Data field
- `image_element/1` - Image with alt text
- `line_element/1` - HR element
- `box_element/1` - Container box
- `aggregate_element/1` - Calculated value
- `expression_element/1` - Expression result

**Utility Functions (2 functions):**
- `render_single_component/3` - Programmatic rendering
- `cleanup_component_cache/0` - Cache cleanup

#### Existing Test File

**File:** `test/ash_reports/heex_renderer/components_test.exs` (11,753 bytes)

**Likely Needs:**
- Additional element type tests
- Style generation tests
- Error handling tests
- Component attribute tests

#### Test Scenarios Needed (90 tests)

**Container Components (16 tests):**
- report_container generates proper div
- Includes class attribute
- Includes data-report attribute
- Includes data-format="heex"
- Accepts rest attributes
- Renders inner_block
- report_header shows title
- Shows timestamp by default
- Hides timestamp when disabled
- Shows metadata when present
- Formats metadata correctly
- report_content renders children
- report_footer shows timestamp
- Shows generation message
- Shows metadata in footer
- Accepts custom classes

**Band Components (8 tests):**
- band_group wraps bands correctly
- Includes data-band-group attribute
- Renders inner_block
- band generates section element
- Includes band type in data attribute
- Applies band styles
- Accepts custom classes
- Renders children elements

**Element Components - Universal (10 tests):**
- element dispatches to correct type
- Resolves element value
- Applies element classes
- Applies element styles
- Includes data-element attribute
- Includes data-element-type
- Accepts custom classes
- Handles nil record
- Handles nil variables
- Renders content correctly

**Element Components - Label (8 tests):**
- label_element renders span
- Shows text attribute
- Falls back to name
- Applies label classes
- Accepts custom classes
- Handles nil text
- Handles empty text
- Preserves HTML entities

**Element Components - Field (10 tests):**
- field_element renders span
- Resolves source from record
- Formats value by element format
- Applies currency format
- Applies percentage format
- Applies date format
- Handles nil record
- Handles missing field
- Includes data-field attribute
- Accepts custom classes

**Element Components - Image (8 tests):**
- image_element renders img tag
- Includes src attribute
- Includes alt attribute
- Defaults alt text
- Applies image styles
- Applies scaling styles
- Accepts custom classes
- Handles missing src

**Element Components - Line (8 tests):**
- line_element renders hr tag
- Applies line styles
- Applies thickness style
- Applies color style
- Applies border-style
- Defaults to solid
- Accepts custom classes
- Handles nil thickness

**Element Components - Box (8 tests):**
- box_element renders div
- Applies border width
- Applies border color
- Applies fill color
- Combines multiple styles
- Renders inner_block
- Accepts custom classes
- Handles nil border/fill

**Element Components - Aggregate (6 tests):**
- aggregate_element renders span
- Includes data-aggregate attribute
- Formats calculated value
- Handles aggregate functions
- Accepts custom classes
- Shows zero for empty

**Element Components - Expression (6 tests):**
- expression_element renders span
- Includes data-expression attribute
- Shows expression result
- Formats result value
- Accepts custom classes
- Handles evaluation errors

**Utility Functions (4 tests):**
- render_single_component renders by type
- Returns error for unknown type
- cleanup_component_cache succeeds
- Handles missing cache gracefully

#### Test Expansion Required

- Add tests for all element types (some may be missing)
- Add style generation edge cases
- Add attribute validation tests
- Add format helper integration tests

#### Success Criteria

- 90 tests total (expanding existing)
- All container components tested
- All band components tested
- All element types tested
- Utility functions verified
- Style/class generation complete

---

### 3.7 LiveViewIntegration (`live_view_integration.ex` - 595 lines) - Fix Existing Tests

#### Current Functionality

**Setup Functions (2 functions):**
- `setup_report_subscriptions/1` - PubSub setup
- `cleanup_pubsub_subscriptions/0` - PubSub cleanup

**Event Handlers (4 functions):**
- `handle_filter_event/2` - Apply filters
- `handle_sort_event/2` - Apply sorting
- `handle_pagination_event/2` - Apply pagination
- `update_report_data/2` - Update data

**LiveView Integration (5 functions):**
- `create_live_report_assigns/1` - Create assigns map
- `broadcast_report_update/2` - Broadcast data update
- `broadcast_report_config_change/2` - Broadcast config change
- `create_event_handlers/2` - Create handler map
- `validate_requirements/0` - Validate Phoenix LiveView

**Streaming Functions (2 functions):**
- `setup_data_streaming/3` - Setup stream
- `handle_stream_update/3` - Update stream

**Filter Functions (1 function):**
- `create_filter_assigns/2` - Create filter config

#### Existing Test File Issues

**File:** `test/ash_reports/heex_renderer/live_view_integration_test.exs` (15,858 bytes)

**Issues to Fix:**
1. **Private function access** - Tests call `apply_filters_to_data/1`, etc. which are private
   - Currently has rescue blocks catching UndefinedFunctionError
   - Need to test through public API or expose test helpers
2. **Socket mocking** - Tests build mock Socket structs
   - May need updates for Phoenix.LiveView changes
3. **Atom validation** - Uses `AshReports.Security.AtomValidator`
   - Need to ensure this module exists or mock it
4. **PubSub testing** - Broadcasts need actual PubSub or mocking

#### Test Scenarios Needed (75 tests)

**Setup and Cleanup (5 tests):**
- Sets up PubSub subscriptions with report ID
- Handles socket without report
- Updates subscription metadata
- Cleanup executes without error
- Cleanup handles missing subscriptions

**Filter Event Handling (15 tests):**
- Applies single filter
- Merges multiple filters
- Filters by string value (case insensitive)
- Filters by exact value
- Filters by numeric value
- Filters by boolean value
- Handles empty filters
- Handles nil field values
- Updates filtered_data in assigns
- Updates render_context
- Preserves original data
- Chains with sort
- Chains with pagination
- Uses AtomValidator for field names
- Prevents atom exhaustion

**Sort Event Handling (12 tests):**
- Sorts by field ascending
- Sorts by field descending
- Sorts string fields
- Sorts numeric fields
- Sorts date fields
- Defaults to ascending
- Validates direction atom
- Uses AtomValidator for direction
- Updates sorted_data in assigns
- Updates render_context
- Preserves filtered data
- Chains with pagination

**Pagination Event Handling (10 tests):**
- Paginates first page
- Paginates middle page
- Paginates last page
- Handles page overflow
- Calculates total from data
- Defaults page to 1
- Defaults per_page to 25
- Updates paginated_data
- Updates render_context
- Preserves sorted/filtered data

**Data Update Handling (5 tests):**
- Updates data in assigns
- Sets last_updated timestamp
- Updates render_context
- Triggers re-render
- Preserves filters/sort/pagination

**LiveView Assigns Creation (8 tests):**
- Creates complete assigns map
- Includes report_content
- Includes report_metadata
- Includes interactive flag
- Includes real_time flag
- Includes filters/sort/pagination
- Builds from socket data
- Calls HeexRenderer internally

**Broadcasting (4 tests):**
- Broadcasts report update
- Broadcasts config change
- Uses correct PubSub topic
- Doesn't crash on error

**Event Handler Creation (4 tests):**
- Creates handlers for filter
- Creates handlers for sort
- Creates handlers for paginate
- Handles empty event types

**Requirement Validation (4 tests):**
- Validates LiveView available
- Validates PubSub configured
- Returns error for missing LiveView
- Returns error for missing PubSub

**Data Streaming (8 tests):**
- Sets up stream with name
- Enables streaming flag
- Inserts items to stream
- Handles empty stream
- Updates existing stream
- Handles concurrent updates
- Preserves stream order
- Cleans up stream

#### Test Fixes Required

1. **Remove private function tests** or refactor to test through public API
2. **Update Socket mocking** to match current Phoenix.LiveView
3. **Mock or stub AtomValidator** if it doesn't exist
4. **Mock PubSub** for broadcast tests
5. **Update filter/sort/pagination tests** to use public event handlers

#### Success Criteria

- 75 tests total (fixing existing)
- All event handlers tested
- All data operations tested
- Broadcasting verified
- Streaming functionality tested
- Atom validation security confirmed
- No private function access
- Mock Socket compatible

---

## 4. Implementation Plan

### Phase 1: Fix Existing Tests (4-6 hours)

#### Task 1.1: Fix Helpers Tests (1.5 hours)
**File:** `test/ash_reports/heex_renderer/helpers_test.exs`

**Subtasks:**
1. Read existing test file to identify failures
2. Update Element/Band struct creation to match schema
3. Fix CSS class output assertions
4. Update style generation assertions
5. Add missing RenderContext where needed
6. Run tests and fix remaining issues
7. Add any missing test coverage for helpers

**Success:** All existing helpers tests pass

#### Task 1.2: Fix Components Tests (1.5 hours)
**File:** `test/ash_reports/heex_renderer/components_test.exs`

**Subtasks:**
1. Read existing test file
2. Update component API calls to match current implementation
3. Fix Phoenix.Component attribute assertions
4. Update assigns structure expectations
5. Add missing element type tests
6. Run tests and iterate

**Success:** All existing component tests pass

#### Task 1.3: Fix LiveView Integration Tests (1.5 hours)
**File:** `test/ash_reports/heex_renderer/live_view_integration_test.exs`

**Subtasks:**
1. Identify private function call issues
2. Refactor to test through public API
3. Mock Socket properly for current Phoenix.LiveView
4. Add AtomValidator module or mock it
5. Mock PubSub for broadcast tests
6. Remove or fix rescue blocks
7. Run tests and iterate

**Success:** All existing LiveView integration tests pass

#### Task 1.4: Update Main HEEX Renderer Test (0.5 hours)
**File:** `test/ash_reports/heex_renderer_test.exs`

**Subtasks:**
1. Add tests for Phase 6.2 chart integration
2. Update metadata assertions for new features
3. Add chart-specific test scenarios

**Success:** Main test file updated and passing

---

### Phase 2: Test Untested Modules (6-8 hours)

#### Task 2.1: Create HeexRenderer Core Tests (2 hours)
**File:** Create comprehensive test coverage for chart integration

**Test Creation:**
1. Create test helper for chart configurations
2. Write 70 tests covering:
   - Basic rendering (15 tests)
   - Chart integration (15 tests)
   - Component rendering (10 tests)
   - Context validation (10 tests)
   - Context preparation (10 tests)
   - LiveView integration (10 tests)
3. Add edge case tests
4. Run and iterate

**Deliverable:** 70 passing tests for HeexRenderer

#### Task 2.2: Create HeexRendererEnhanced Tests (1.5 hours)
**File:** `test/ash_reports/renderers/heex_renderer_enhanced_test.exs`

**Test Creation:**
1. Write 45 tests covering:
   - Enhanced rendering (10 tests)
   - LiveView code generation (10 tests)
   - Chart component generation (10 tests)
   - Asset integration (10 tests)
   - Error handling (5 tests)
2. Add edge case tests
3. Run and iterate

**Deliverable:** 45 passing tests for HeexRendererEnhanced

#### Task 2.3: Create TemplateOptimizer Tests (1 hour)
**File:** `test/ash_reports/heex_renderer/template_optimizer_test.exs`

**Test Creation:**
1. Write 35 tests covering:
   - Optimization functions (15 tests)
   - Caching operations (10 tests)
   - Error handling (5 tests)
   - Cache key generation (5 tests)
2. Add edge case tests
3. Run and iterate

**Deliverable:** 35 passing tests for TemplateOptimizer

#### Task 2.4: Create ChartTemplates Tests (2.5 hours)
**File:** `test/ash_reports/heex_renderer/chart_templates_test.exs`

**Test Creation:**
1. Write 85 tests covering:
   - Single chart (12 tests)
   - Dashboard grid (12 tests)
   - Filter dashboard (12 tests)
   - Real-time dashboard (12 tests)
   - Tabbed charts (12 tests)
   - Localization (25 tests - can group)
2. Add edge case tests
3. Run and iterate

**Deliverable:** 85 passing tests for ChartTemplates

---

### Phase 3: Expand Partial Coverage (2-4 hours)

#### Task 3.1: Expand Helpers Test Coverage (1 hour)
**Action:** Add missing tests to existing file

**Add:**
- Format helper edge cases
- All localization paths
- Utility function edge cases

**Deliverable:** Complete helpers coverage

#### Task 3.2: Expand Components Test Coverage (1 hour)
**Action:** Add missing tests to existing file

**Add:**
- All element types
- Style generation edge cases
- Error handling

**Deliverable:** Complete components coverage

#### Task 3.3: Expand LiveView Integration Coverage (1 hour)
**Action:** Add missing tests to existing file

**Add:**
- Streaming edge cases
- Real-time update scenarios
- Filter creation edge cases

**Deliverable:** Complete LiveView integration coverage

---

## 5. Test Data Requirements

### Mock Data Structures

#### Chart Configurations
```elixir
def build_chart_config(type \\ :bar) do
  %{
    id: "test_chart_#{:rand.uniform(1000)}",
    type: type,
    data: build_chart_data(type),
    title: "Test Chart",
    provider: :chartjs,
    interactive: true,
    real_time: false,
    interactions: [:click, :hover],
    update_interval: 30_000
  }
end

def build_chart_data(:bar) do
  [
    %{label: "Jan", value: 100},
    %{label: "Feb", value: 150},
    %{label: "Mar", value: 200}
  ]
end

def build_chart_data(:pie) do
  [
    %{label: "Category A", value: 30},
    %{label: "Category B", value: 50},
    %{label: "Category C", value: 20}
  ]
end

def build_chart_data(:line) do
  [
    %{x: ~D[2024-01-01], y: 100},
    %{x: ~D[2024-02-01], y: 150},
    %{x: ~D[2024-03-01], y: 200}
  ]
end
```

#### Dashboard Configurations
```elixir
def build_dashboard_config do
  %{
    dashboard_id: "test_dashboard",
    charts: [
      build_chart_config(:bar),
      build_chart_config(:pie)
    ],
    layout: :grid,
    grid_columns: 12,
    real_time: true,
    title: "Test Dashboard"
  }
end

def build_filter_dashboard_config do
  %{
    main_chart: build_chart_config(:line),
    filters: [:date_range, :region, :category],
    sidebar_position: :left
  }
end

def build_realtime_dashboard_config do
  %{
    charts: [build_chart_config(:line)],
    update_interval: 5000,
    show_metrics: true
  }
end

def build_tabbed_charts_config do
  %{
    tabs: [
      %{id: "overview", title: "Overview", chart_config: build_chart_config(:bar)},
      %{id: "details", title: "Details", chart_config: build_chart_config(:pie)}
    ]
  }
end
```

#### RenderContext with Charts
```elixir
def build_context_with_charts do
  report = build_test_report()
  data_result = build_test_data_result()
  config = %{
    format: :heex,
    charts: [build_chart_config(:bar)],
    heex: %{
      liveview_enabled: true,
      interactive: true,
      real_time_updates: false
    }
  }

  RenderContext.new(report, data_result, config)
end
```

#### Socket Mocks
```elixir
def build_mock_socket(assigns \\ %{}) do
  %Phoenix.LiveView.Socket{
    assigns: Map.merge(%{
      report: build_test_report(),
      data: build_test_data(),
      config: %{},
      metadata: %{subscriptions: []}
    }, assigns)
  }
end
```

### Shared Test Helpers

**Add to** `test/support/renderer_test_helpers.ex`:
- `build_chart_config/1`
- `build_dashboard_config/0`
- `build_context_with_charts/0`
- Chart data builders

**Add to** `test/support/live_view_test_helpers.ex` (or create):
- `build_mock_socket/1`
- `mock_pubsub_broadcast/2`
- `simulate_filter_event/2`
- `simulate_sort_event/2`
- `simulate_pagination_event/2`

---

## 6. Integration Points

### With Existing Test Infrastructure

**Reuse from Section 2.4.1:**
- `test/support/renderer_test_helpers.ex`
  - `build_render_context/1`
  - `build_mock_report/0`
  - `build_mock_layout_state/1`

**New Dependencies:**
- Phoenix.LiveView.Socket mocking
- Phoenix.PubSub mocking or test mode
- ETS table management for cache tests
- Chart data generation helpers

### With Phase 6.2 Chart Integration

**Chart Module Integration:**
- `AshReports.LiveView.ChartHooks` - For hook generation tests
- `AshReports.HtmlRenderer.AssetManager` - For asset link tests
- `AshReports.Security.AtomValidator` - For atom safety tests

**May Need to Create Stubs For:**
- `AshReports.LiveView.ChartLiveComponent` - Chart component module
- `AshReports.PubSub` - PubSub name configuration
- Chart provider modules if not implemented

### Cross-Module Testing

**HeexRenderer depends on:**
- Components module
- Helpers module
- LiveViewIntegration module
- TemplateOptimizer module (optional)
- ChartTemplates module (for charts)

**Test Strategy:**
- Unit test each module independently
- Integration test HeexRenderer with all dependencies
- Mock external dependencies (PubSub, AssetManager)
- Use real implementations for internal modules

---

## 7. Success Metrics

### Test Coverage Targets

| Module | Lines | Target Tests | Target Coverage |
|--------|-------|--------------|-----------------|
| heex_renderer.ex | 719 | 70 | >90% |
| heex_renderer_enhanced.ex | 379 | 45 | >85% |
| template_optimizer.ex | 107 | 35 | >95% |
| chart_templates.ex | 543 | 85 | >80% |
| helpers.ex | 655 | 80 | >85% |
| components.ex | 788 | 90 | >85% |
| live_view_integration.ex | 595 | 75 | >85% |
| **Total** | **3,786** | **480** | **>85%** |

### Test Quality Metrics

**Code Quality:**
- No test warnings or compilation errors
- All tests follow ExUnit best practices
- Descriptive test names
- Proper setup/teardown
- No test interdependencies

**Coverage Quality:**
- All public API functions tested
- All error paths tested
- All edge cases covered
- Integration scenarios tested
- Performance benchmarks included

**Maintainability:**
- Test helpers properly organized
- Mock data reusable
- Tests run in parallel (async: true where safe)
- Fast test execution (<10s for full suite)
- Clear test documentation

### Success Criteria Checklist

- [ ] All Phase 1 tests fixed and passing (helpers, components, live_view_integration)
- [ ] All Phase 2 tests created and passing (4 new test files)
- [ ] All Phase 3 expansions complete (additional coverage)
- [ ] Overall test coverage >85%
- [ ] No compilation warnings
- [ ] No test flakiness
- [ ] Test suite runs in <10 seconds
- [ ] All edge cases documented
- [ ] Test helpers properly organized
- [ ] Integration tests passing
- [ ] Performance benchmarks established

### Performance Benchmarks

**Rendering Performance:**
- HeexRenderer.render_with_context/2: <10ms for 100 records
- Chart integration overhead: <5ms per chart
- Template optimization: <1ms for typical template

**Memory Usage:**
- Rendering 1000 records: <50MB memory increase
- Template cache: <10MB for 100 templates
- Chart component generation: <5MB per chart

**Test Performance:**
- Full test suite: <10 seconds
- Individual test file: <1 second
- Cache tests: <100ms

---

## 8. Risk Assessment and Mitigation

### High Risk Items

#### Risk 1: Private Function Testing
**Impact:** High - Many existing tests call private functions

**Mitigation:**
- Phase 1.3 specifically addresses this
- Refactor to test through public API
- Add test-only public wrappers if necessary
- Document workarounds

#### Risk 2: Phoenix.LiveView Compatibility
**Impact:** High - Socket mocking may break with Phoenix updates

**Mitigation:**
- Use minimal Socket mocking
- Test against current Phoenix.LiveView version
- Add version checks if needed
- Consider using Phoenix.ConnTest patterns

#### Risk 3: Chart Integration Dependencies
**Impact:** Medium - Phase 6.2 modules may not be complete

**Mitigation:**
- Identify missing dependencies early (Task 2.1)
- Create minimal stubs for missing modules
- Test with and without charts
- Document required modules

### Medium Risk Items

#### Risk 4: ETS Cache Race Conditions
**Impact:** Medium - Cache tests may be flaky

**Mitigation:**
- Use unique cache table names per test
- Clear cache in setup
- Test concurrent access explicitly
- Document thread-safety expectations

#### Risk 5: Localization Test Maintenance
**Impact:** Medium - 25 localized strings to test

**Mitigation:**
- Group localization tests efficiently
- Use test macros for repetitive checks
- Document expected translations
- Consider property-based testing

#### Risk 6: Test Suite Performance
**Impact:** Medium - 480+ tests may be slow

**Mitigation:**
- Use async: true wherever safe
- Optimize mock data creation
- Profile slow tests
- Parallelize test execution

### Low Risk Items

#### Risk 7: Template Comparison Fragility
**Impact:** Low - HEEX output comparison may be brittle

**Mitigation:**
- Use string contains checks, not exact matches
- Normalize whitespace in comparisons
- Test semantic structure, not exact format
- Document output expectations

---

## 9. Timeline and Milestones

### Day 1: Fix Existing Tests + Start Untested Modules (8 hours)

**Morning (4 hours):**
- 08:00-09:30: Task 1.1 - Fix Helpers Tests
- 09:30-11:00: Task 1.2 - Fix Components Tests
- 11:00-12:30: Task 1.3 - Fix LiveView Integration Tests
- 12:30-13:00: Task 1.4 - Update Main HEEX Renderer Test

**Afternoon (4 hours):**
- 13:00-15:00: Task 2.1 - Create HeexRenderer Core Tests (2 hours)
- 15:00-16:30: Task 2.2 - Create HeexRendererEnhanced Tests (1.5 hours)
- 16:30-17:30: Task 2.3 - Create TemplateOptimizer Tests (1 hour)

**Milestone:** All existing tests fixed, 3/4 untested modules have tests

### Day 2: Complete Untested Modules + Expand Coverage (8 hours)

**Morning (4 hours):**
- 08:00-10:30: Task 2.4 - Create ChartTemplates Tests (2.5 hours)
- 10:30-11:30: Task 3.1 - Expand Helpers Test Coverage (1 hour)
- 11:30-12:30: Task 3.2 - Expand Components Test Coverage (1 hour)

**Afternoon (4 hours):**
- 13:00-14:00: Task 3.3 - Expand LiveView Integration Coverage (1 hour)
- 14:00-15:00: Run full test suite, fix failures
- 15:00-16:00: Performance benchmarking
- 16:00-17:00: Documentation and cleanup

**Milestone:** All tests complete, coverage >85%, documentation updated

### Buffer Time (2-4 hours)

**Contingency for:**
- Unexpected test failures
- Missing dependencies
- Complex edge cases
- Performance issues
- Documentation improvements

---

## 10. Documentation Requirements

### Test Documentation

**For Each Test File:**
- Module docstring explaining what's being tested
- Test group descriptions (describe blocks)
- Complex test explanations via comments
- Edge case documentation
- Mock data documentation

### Code Comments

**Required Comments:**
- Why certain tests are structured a certain way
- Explanation of complex assertions
- Documentation of known limitations
- Links to related issues or decisions
- Performance expectations

### Test Helper Documentation

**For Each Helper:**
- Purpose and usage
- Parameters and return values
- Example usage
- Related helpers

### Feature Summary Document

**At Completion:**
- Total tests created/fixed
- Coverage achieved per module
- Known issues or limitations
- Performance benchmarks
- Recommendations for future work

**Template:** Follow format from `stage2-4-1-html-renderer-core-tests-summary.md`

---

## 11. Acceptance Criteria

### Test Coverage
- [ ] All 7 modules have test files
- [ ] HeexRenderer: 70+ tests, >90% coverage
- [ ] HeexRendererEnhanced: 45+ tests, >85% coverage
- [ ] TemplateOptimizer: 35+ tests, >95% coverage
- [ ] ChartTemplates: 85+ tests, >80% coverage
- [ ] Helpers: 80+ tests, >85% coverage (fixed)
- [ ] Components: 90+ tests, >85% coverage (expanded)
- [ ] LiveViewIntegration: 75+ tests, >85% coverage (fixed)

### Code Quality
- [ ] No compilation warnings
- [ ] No test warnings
- [ ] All tests pass consistently
- [ ] No flaky tests
- [ ] Tests run in <10 seconds
- [ ] Test helpers properly organized

### Functionality Coverage
- [ ] All public API functions tested
- [ ] All error paths tested
- [ ] All edge cases covered
- [ ] Chart integration fully tested
- [ ] LiveView integration fully tested
- [ ] Localization fully tested (4 languages)
- [ ] Security features tested (atom validation)

### Integration
- [ ] Tests integrate with existing infrastructure
- [ ] Mock data reusable across tests
- [ ] Dependencies properly mocked or stubbed
- [ ] Performance benchmarks established
- [ ] Memory usage validated

### Documentation
- [ ] Test files have clear docstrings
- [ ] Complex tests have explanatory comments
- [ ] Test helpers documented
- [ ] Feature summary document created
- [ ] Known issues documented

---

## 12. Follow-up Actions

### After Test Implementation

**Immediate:**
1. Run coverage analysis: `mix test --cover`
2. Identify any remaining gaps
3. Profile test performance: identify slow tests
4. Review test output for warnings

**Short-term (1 week):**
1. Monitor for test flakiness
2. Optimize slow tests if needed
3. Add missing edge cases discovered
4. Update documentation based on feedback

**Long-term (1 month):**
1. Review test maintainability
2. Consider property-based testing for complex scenarios
3. Add integration tests with real Phoenix.LiveView
4. Performance regression testing

### Recommended Future Work

**Test Enhancements:**
- Property-based testing for template generation
- Visual regression testing for HEEX output
- Load testing for concurrent rendering
- Security testing for XSS in chart data

**Tool Integration:**
- Add ExCoveralls for detailed coverage reports
- Set up continuous coverage tracking
- Add performance benchmarking to CI
- Automated test documentation generation

**Feature Improvements:**
- Additional chart template types
- More localization languages
- Enhanced accessibility testing
- Browser compatibility testing

---

## Appendix A: Test File Structure

### Directory Structure
```
test/
├── ash_reports/
│   ├── heex_renderer_test.exs                    # Main renderer (existing, needs update)
│   └── heex_renderer/
│       ├── components_test.exs                   # Components (existing, needs expansion)
│       ├── helpers_test.exs                      # Helpers (existing, needs fixes)
│       ├── live_view_integration_test.exs        # LiveView (existing, needs fixes)
│       ├── template_optimizer_test.exs           # NEW: Template optimizer
│       └── chart_templates_test.exs              # NEW: Chart templates
└── support/
    ├── renderer_test_helpers.ex                  # Existing, add chart helpers
    └── live_view_test_helpers.ex                 # May need creation/expansion
```

### Test Naming Convention

**Pattern:** `<module>_<function>_<scenario>_test`

**Examples:**
- `heex_renderer_render_with_context_includes_charts_test`
- `template_optimizer_optimize_template_removes_whitespace_test`
- `chart_templates_single_chart_shows_real_time_indicator_test`

### Test Organization

**Within Each File:**
```elixir
defmodule AshReports.Module.SubModuleTest do
  use ExUnit.Case, async: true

  # Module aliases
  # Test setup

  describe "public_function_name/arity" do
    test "happy path scenario" do
      # arrange
      # act
      # assert
    end

    test "error scenario" do
      # arrange
      # act
      # assert
    end

    test "edge case scenario" do
      # arrange
      # act
      # assert
    end
  end

  # Test helper functions (private)
end
```

---

## Appendix B: Key Differences from Section 2.4.1

### Similarities
- Both test rendering pipelines
- Both use RenderContext
- Both test template generation
- Both test metadata generation
- Both have CSS/style generation

### Differences

**HTML Renderer (2.4.1):**
- Generates complete HTML documents
- Embeds CSS and JavaScript inline
- Standalone output (no framework dependency)
- EEx template compilation
- Chart.js/D3.js/Plotly static integration

**HEEX Renderer (2.4.2):**
- Generates Phoenix.Component templates
- Relies on Phoenix LiveView
- Dynamic, interactive output
- HEEX syntax (not EEx)
- LiveView chart components (real-time)
- PubSub integration
- Streaming support
- Event handling (filter, sort, pagination)

### Testing Approach Differences

**HTML Renderer Tests:**
- Test complete HTML output
- Test JavaScript generation
- Test static chart rendering
- No LiveView dependencies

**HEEX Renderer Tests:**
- Test HEEX template structure
- Test Phoenix.Component integration
- Test LiveView compatibility
- Mock Socket and PubSub
- Test real-time updates
- Test event handling

---

## Appendix C: Module Dependency Graph

```
HeexRenderer
├── Components (required)
│   └── Helpers (required)
├── LiveViewIntegration (optional, for interactivity)
│   └── RenderContext (required)
├── TemplateOptimizer (optional, for optimization)
└── ChartTemplates (optional, for charts)
    └── RenderContext (required)

HeexRendererEnhanced
├── HeexRenderer (required)
├── ChartTemplates (required)
├── LiveView.ChartHooks (required)
└── HtmlRenderer.AssetManager (required)

TemplateOptimizer
└── (no dependencies)

ChartTemplates
└── RenderContext (required)

Helpers
└── Element/Band/Report structs (required)

Components
├── Phoenix.Component (required)
└── Helpers (implicit usage)

LiveViewIntegration
├── Phoenix.LiveView (required)
├── Phoenix.PubSub (required)
├── RenderContext (required)
└── Security.AtomValidator (required)
```

### Test Dependency Strategy

**Approach:**
1. Test independent modules first (TemplateOptimizer, Helpers)
2. Test dependent modules next (Components, ChartTemplates)
3. Test integration modules last (HeexRenderer, HeexRendererEnhanced, LiveViewIntegration)

**Mocking Strategy:**
- Mock external dependencies (PubSub, LiveView features)
- Use real implementations for internal modules
- Create test stubs for missing Phase 6.2 modules

---

## Summary

This planning document provides a comprehensive roadmap for implementing test coverage for Section 2.4.2: HEEX Renderer and LiveView Tests. The plan covers:

- **7 modules** with varying coverage levels
- **480+ tests** to be created or fixed
- **2 days** of implementation time
- **>85% coverage** target across all modules
- Clear task breakdown with time estimates
- Risk assessment and mitigation strategies
- Success criteria and acceptance tests

The plan follows the same structure as Section 2.4.1 but accounts for the unique challenges of testing Phoenix LiveView integration, real-time features, and HEEX template generation.
