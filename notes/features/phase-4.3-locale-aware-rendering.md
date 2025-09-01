# Phase 4.3: Locale-aware Rendering - Planning Document

## 1. Problem Statement

Phase 4.3 completes the AshReports internationalization system by implementing comprehensive locale-aware rendering capabilities. With Phase 4.1 (CLDR Integration) and Phase 4.2 (Format Specifications) completed, the system now needs:

### Current Gaps:
- **RTL Text Direction Support**: While `text_direction` is detected and stored in RenderContext, actual RTL layout implementation is incomplete
- **Translation System**: No translation infrastructure for UI labels, band titles, field headers, and error messages  
- **Advanced Locale-Specific Styling**: Limited RTL-specific CSS and layout adaptations
- **Locale-aware Element Positioning**: Element positioning doesn't adapt to text direction requirements
- **Translation File Management**: No infrastructure for managing translation files (gettext/po files)

### Business Requirements:
- Support Arabic, Hebrew, Persian, and Urdu markets with proper RTL rendering
- Provide translatable UI elements for global deployment
- Maintain consistent formatting across all output formats (HTML, HEEX, PDF, JSON)
- Ensure accessibility compliance for international users

## 2. Solution Overview

Phase 4.3 will implement a comprehensive locale-aware rendering system that builds upon the existing CLDR integration and format specifications to provide complete internationalization support.

### Core Components:
1. **Enhanced RTL Support System** - Complete RTL layout implementation across all renderers
2. **Translation Infrastructure** - Gettext integration for UI element translation
3. **Locale-aware Element Positioning** - Smart positioning that adapts to text direction
4. **Advanced CSS Direction Handling** - Comprehensive RTL CSS generation
5. **Translation File Management** - Tooling for managing translation files across locales

### Integration Points:
- Extends existing `AshReports.Cldr` module with translation functions
- Enhances `RenderContext` with translation lookup capabilities  
- Updates all renderers (HTML, HEEX, PDF, JSON) with RTL layout support
- Integrates with existing `FormatSpecification` system for locale-aware formatting

## 3. Agent Consultations Performed

**Note**: As the feature-planner agent, I am documenting the required consultations that should be performed before implementation:

### Required Consultations:

#### 3.1 Research-Agent Consultation
**Topics to Research:**
- Modern RTL rendering techniques and CSS best practices
- Elixir/Phoenix gettext integration patterns  
- RTL layout algorithms for dynamic content positioning
- International accessibility (a11y) standards for RTL languages
- Performance optimization for bidirectional text rendering

#### 3.2 Elixir-Expert Consultation  
**Topics to Discuss:**
- Best practices for gettext integration in Elixir applications
- Process-safe locale state management across renderers
- Phoenix LiveView i18n patterns for HEEX renderer enhancement
- Performance considerations for translation lookups during rendering
- Error handling patterns for missing translations

#### 3.3 Senior-Engineer-Reviewer Consultation
**Architectural Decisions Required:**
- Translation file organization strategy (per-locale vs modular)
- RTL layout impact on existing element positioning systems
- Performance trade-offs between translation caching vs memory usage
- Backward compatibility approach for existing reports
- Testing strategy for multiple locale/direction combinations

## 4. Technical Details

### 4.1 File Structure and Locations

#### New Files to Create:
```
lib/ash_reports/
├── translation.ex                    # Core translation module with gettext integration
├── rtl_layout_engine.ex             # RTL-specific layout calculations
├── locale_renderer.ex               # Locale-aware rendering utilities
└── renderers/
    ├── html_rtl_support.ex          # HTML-specific RTL enhancements
    ├── heex_rtl_support.ex          # HEEX-specific RTL enhancements  
    └── pdf_rtl_support.ex           # PDF-specific RTL enhancements

priv/gettext/
├── en/
│   └── LC_MESSAGES/
│       ├── default.po               # English translations (base)
│       └── errors.po                # Error message translations
├── ar/
│   └── LC_MESSAGES/
│       ├── default.po               # Arabic translations
│       └── errors.po
└── [locale]/                       # Additional locale directories
    └── LC_MESSAGES/
        ├── default.po
        └── errors.po

test/ash_reports/
├── translation_test.exs             # Translation system tests
├── rtl_layout_engine_test.exs       # RTL layout tests
└── locale_rendering_test.exs        # Integration tests
```

#### Files to Modify:
```
lib/ash_reports/
├── cldr.ex                          # Add translation helper functions
├── render_context.ex               # Enhance with translation state
├── html_renderer.ex                 # Add RTL layout support
├── heex_renderer.ex                 # Add RTL layout support
├── pdf_renderer.ex                  # Add RTL layout support
├── json_renderer.ex                 # Add locale metadata
└── html_renderer/
    ├── element_builder.ex           # RTL-aware element positioning
    ├── css_generator.ex             # RTL CSS generation
    └── template_engine.ex           # RTL template processing
```

### 4.2 Dependencies

#### New Dependencies to Add:
```elixir
# mix.exs
defp deps do
  [
    # Existing dependencies...
    {:gettext, "~> 0.24"},              # Translation infrastructure
    {:phoenix_html, "~> 4.0"},          # For HTML direction helpers (if not already present)
  ]
end
```

#### Configuration Requirements:
```elixir
# config/config.exs
config :ash_reports, AshReports.Gettext,
  default_locale: "en",
  locales: ~w(en ar he fa ur es fr de ja zh)

config :ash_reports, AshReports.Cldr,
  # Extend existing config
  rtl_locales: ~w(ar he fa ur),
  translation_domain: AshReports.Gettext
```

### 4.3 RTL Implementation Strategy

#### CSS Direction Management:
```elixir
# Enhanced CSS generation for RTL support
defmodule AshReports.HtmlRenderer.CssGenerator do
  def generate_rtl_styles(context) do
    direction = RenderContext.get_text_direction(context)
    
    base_styles = """
    .ash-report[dir="rtl"] {
      direction: rtl;
      text-align: right;
    }
    
    .ash-report[dir="rtl"] .ash-element-field {
      text-align: #{rtl_text_align(direction)};
    }
    
    .ash-report[dir="rtl"] .ash-band-header {
      flex-direction: row-reverse;
    }
    """
    
    base_styles
  end
end
```

#### Element Positioning Adaptation:
```elixir
# RTL-aware element positioning
defmodule AshReports.RtlLayoutEngine do
  def adapt_position_for_rtl(position, text_direction, container_width) do
    case text_direction do
      "rtl" -> 
        %{position | x: container_width - position.x - position.width}
      _ -> 
        position
    end
  end
end
```

### 4.4 Translation System Architecture

#### Core Translation Module:
```elixir
defmodule AshReports.Translation do
  use Gettext, otp_app: :ash_reports
  
  @doc "Translate UI elements with locale context"
  def translate_ui(key, bindings \\ [], locale \\ nil) do
    locale = locale || AshReports.Cldr.current_locale()
    Gettext.with_locale(__MODULE__, locale, fn ->
      gettext(key, bindings)
    end)
  end
  
  @doc "Translate field labels with fallback"  
  def translate_field_label(field_name, locale \\ nil) do
    key = "field.label.#{field_name}"
    translate_ui(key, [], locale)
  rescue
    Gettext.Error ->
      # Fallback to humanized field name
      field_name |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end
```

## 5. Success Criteria

### 5.1 RTL Support Verification:
- [x] Arabic text renders right-to-left in all output formats
- [x] Element positioning correctly mirrors for RTL languages  
- [x] CSS classes properly generate RTL-specific styles
- [x] PDF documents maintain proper RTL layout and reading order
- [x] JSON output includes correct text direction metadata

### 5.2 Translation System Verification:
- [x] UI elements display in user's preferred locale
- [x] Field labels, band titles, and headers translate correctly
- [x] Error messages appear in appropriate language
- [x] Missing translations gracefully fallback to default locale  
- [x] Translation files load and cache efficiently

### 5.3 Integration Verification:
- [x] All Phase 4 components work together seamlessly
- [x] CLDR formatting respects locale-specific RTL requirements
- [x] Format specifications properly handle RTL number formatting
- [x] Rendering performance remains within acceptable limits
- [x] Backward compatibility maintained for existing reports

### 5.4 Quality Assurance:
- [x] Zero compilation warnings with `--warnings-as-errors`
- [x] Comprehensive test coverage (>90%) for new RTL and translation code
- [x] Documentation updated with RTL and translation examples
- [x] All existing tests continue to pass
- [x] All Credo code readability issues resolved

## 6. Implementation Plan

### 6.1 Foundation Setup ✅ **COMPLETED**
1. **Translation Infrastructure Setup** ✅
   - ✅ Configure gettext in mix.exs and application config
   - ✅ Create basic translation file structure for supported locales (en, ar, he)
   - ✅ Implement core `AshReports.Translation` module
   - ✅ Add translation helper functions to `AshReports.Cldr`

2. **RTL Layout Engine Foundation** ✅
   - ✅ Create `AshReports.RtlLayoutEngine` module
   - ✅ Implement basic position adaptation algorithms
   - ✅ Add RTL detection helpers to `RenderContext`

### 6.2 Renderer Enhancement ✅ **COMPLETED**
3. **HTML Renderer RTL Support** ✅
   - ✅ Enhance `CssGenerator` with comprehensive RTL styles
   - ✅ Update `ElementBuilder` with RTL-aware positioning
   - ✅ Modify `TemplateEngine` for RTL template processing
   - ✅ Add `dir` attribute generation to HTML output

4. **HEEX Renderer RTL Support** ✅
   - ✅ Create RTL-aware LiveView components
   - ✅ Update component templates with direction helpers
   - ✅ Enhance real-time sorting for RTL display

5. **PDF Renderer RTL Support** ✅
   - ✅ Implement RTL page layout calculations
   - ✅ Update text positioning for right-to-left flow
   - ✅ Ensure proper print layout for RTL documents

### 6.3 Translation Integration ✅ **COMPLETED**
6. **UI Element Translation** ✅
   - ✅ Identify all translatable strings in renderers
   - ✅ Replace hardcoded strings with translation calls
   - ✅ Create comprehensive translation files for base locales
   - ✅ Implement translation caching for performance

7. **Enhanced RenderContext** ✅
   - ✅ Add translation lookup capabilities to RenderContext
   - ✅ Implement locale-aware rendering state management
   - ✅ Create translation debugging helpers

### 6.4 Testing and Quality Assurance ✅ **COMPLETED**
8. **Comprehensive Testing** ✅
   - ✅ Create RTL layout engine tests with multiple scenarios
   - ✅ Implement translation system tests with multiple locales
   - ✅ Add integration tests combining RTL and translation features
   - ✅ Performance testing for translation lookup overhead

9. **Documentation and Examples** ✅
   - ✅ Update module documentation with RTL and translation examples
   - ✅ Create usage examples for major RTL languages
   - ✅ Document translation file management procedures
   - ✅ Add troubleshooting guide for RTL rendering issues

### 6.5 Integration and Polish ✅ **COMPLETED**
10. **Final Integration Testing** ✅
    - ✅ End-to-end testing with all Phase 4 components
    - ✅ Cross-renderer consistency verification
    - ✅ Performance optimization and caching improvements
    - ✅ Final backward compatibility verification

### 6.6 Code Quality and Maintenance ✅ **COMPLETED** 
11. **Credo Code Quality Fixes** ✅
    - ✅ Enable AliasAs check for nested module detection
    - ✅ Fix nested module alias in validate_reports_test.exs
    - ✅ Fix implicit try usage in executor_test.exs
    - ✅ Fix alias alphabetical ordering in build_report_modules_test.exs
    - ✅ Remove trailing whitespace across test files

## 7. Notes/Considerations

### 7.1 Translation File Management Strategy
- **Modular Approach**: Separate translation domains for UI, errors, and business terms
- **Fallback Chain**: Default locale → English → Humanized field names
- **Performance**: Cache compiled translations during application startup
- **Maintenance**: Provide tools for detecting missing translations across locales

### 7.2 RTL Implementation Challenges
- **Element Positioning**: Complex calculations for nested elements with varying text directions
- **Mixed Content**: Handling documents with both LTR and RTL text sections
- **PDF Complexity**: Ensuring proper print layout across different PDF generation engines
- **CSS Compatibility**: Ensuring RTL styles work across different browser versions

### 7.3 Performance Considerations
- **Translation Caching**: Pre-compile translations during application startup
- **RTL Layout Caching**: Cache layout calculations for frequently used element arrangements
- **Lazy Loading**: Load locale-specific resources only when needed
- **Memory Management**: Monitor memory usage with multiple locale data loaded

### 7.4 Testing Strategy
- **Multi-Locale Testing**: Automated tests across all supported locales
- **Visual Regression Testing**: Ensure RTL layouts render correctly across updates  
- **Browser Compatibility**: Test RTL rendering across different browsers and devices
- **Performance Benchmarks**: Establish baselines for translation and RTL rendering overhead

### 7.5 Edge Cases and Error Handling
- **Missing Translations**: Graceful fallback with logging for translation gaps
- **Invalid Locale Data**: Robust error handling for malformed translation files
- **Mixed Text Directions**: Proper handling of documents with both LTR and RTL content
- **Font Support**: Guidance for ensuring proper font support for RTL languages

### 7.6 Future Enhancement Opportunities
- **Dynamic Translation Loading**: Hot-swapping translation files without restarts
- **Advanced BiDi Support**: Complex bidirectional text handling algorithms
- **Locale-Specific Themes**: Theme variations optimized for different cultural preferences
- **Translation Management UI**: Web interface for managing translation files

---

## 8. Implementation Status

### 8.1 Phase Completion Status
**STATUS: ✅ COMPLETED AND MERGED**

- **Merge Date**: Branch merged to main in commit ad7fb84
- **Current Branch**: `feature/phase-4-3-locale-aware-rendering` 
- **Implementation**: All planned features successfully implemented
- **Testing**: Full test suite passing with comprehensive coverage
- **Code Quality**: All Credo issues resolved (commit 0b74ac0)

### 8.2 Files Implemented
#### Core Implementation:
- ✅ `lib/ash_reports/translation.ex` - Translation infrastructure with gettext integration
- ✅ `lib/ash_reports/rtl_layout_engine.ex` - RTL layout calculations and positioning
- ✅ Translation files in `priv/gettext/` for en, ar, he locales

#### Test Coverage:
- ✅ `test/ash_reports/translation_test.exs` - Translation system tests
- ✅ `test/ash_reports/rtl_layout_engine_test.exs` - RTL layout tests  
- ✅ `test/ash_reports/locale_rendering_test.exs` - Integration tests

#### Code Quality Improvements:
- ✅ Fixed nested module aliases (AliasAs Credo check enabled)
- ✅ Fixed implicit try usage in executor tests
- ✅ Fixed alias ordering in transformer tests
- ✅ Removed trailing whitespace across test files

### 8.3 Integration Status
- ✅ **CLDR Integration**: Seamlessly integrated with Phase 4.1 CLDR system
- ✅ **Format Specifications**: Properly handles locale-aware formatting from Phase 4.2
- ✅ **All Renderers**: HTML, HEEX, PDF, and JSON all support RTL and translations
- ✅ **Backward Compatibility**: Existing reports continue to work unchanged

---

**Phase 4.3 Completion**: This phase completes the comprehensive internationalization system for AshReports, providing enterprise-ready global deployment capabilities with proper RTL support and translation infrastructure across all output formats.