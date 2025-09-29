# Feature Planning: Typst Runtime Integration (Stage 1.1)

**Feature ID**: typst-runtime-integration-1.1
**Planning Date**: 2025-01-27
**Status**: 🚧 In Progress
**Stage**: 1.1 of Typst Refactor Plan

## Problem Statement

**Current Situation**: AshReports currently uses ChromicPDF for PDF generation, which follows the traditional HTML→PDF conversion approach. This method is slow, especially for large documents, and doesn't provide the performance needed for enterprise-scale reporting.

**Performance Issues**:
- Large reports (100+ pages) can take several minutes to generate
- Memory usage is high during HTML→PDF conversion
- Limited styling control and typography options
- Dependency on Puppeteer/Chrome which is heavy and resource-intensive

**Impact Analysis**:
- **User Experience**: Slow report generation affects user productivity
- **System Performance**: High memory usage limits concurrent report generation
- **Scalability**: Current approach doesn't scale well for enterprise workloads
- **Development Experience**: Complex CSS→PDF conversion debugging

## Solution Overview

**Approach**: Integrate Typst as a modern document compilation engine to replace the current HTML→PDF pipeline. Typst offers 18x faster compilation speed compared to traditional engines and provides native multi-format output support.

**Key Design Decisions**:
1. **Integration Method**: Use `elixir_typst` NIF bindings for optimal performance
2. **Template Management**: File-based template system with hot-reloading for development
3. **Error Handling**: Comprehensive error handling with fallback mechanisms
4. **Caching Strategy**: ETS-based template caching for performance
5. **Supervision**: Proper OTP supervision for NIF stability

## Agent Consultations Performed

### Research Agent Consultation
**Topic**: Typst integration patterns and elixir_typst 0.1.7 API
**Key Findings**:
- elixir_typst provides Rust NIF bindings for direct Typst compilation
- Requires Rust toolchain for compilation during deps.compile
- API supports both string templates and file-based compilation
- Memory management is handled by the NIF, reducing BEAM VM overhead

**Documentation Resources**:
- [elixir_typst 0.1.7 Documentation](https://hexdocs.pm/elixir_typst/0.1.7)
- [Typst Language Reference](https://typst.app/docs/)
- [Rustler NIF Development](https://github.com/rusterlium/rustler)

### Elixir Expert Consultation
**Topic**: OTP supervision patterns for NIF integration
**Key Recommendations**:
- Use GenServer wrapper for NIF calls to handle crashes gracefully
- Implement circuit breaker pattern for NIF failure handling
- Use ETS for template caching with automatic cleanup
- Follow Elixir error handling conventions with `{:ok, result}` | `{:error, reason}` tuples

**Integration Patterns**:
- Supervision tree placement under AshReports.Application
- Template manager as a GenServer for state management
- Binary wrapper module for direct NIF interface

### Senior Engineer Review Consultation
**Topic**: Architecture decisions and error handling strategy
**Key Architectural Decisions**:
1. **Modular Design**: Separate concerns into distinct modules (BinaryWrapper, TemplateManager, BandEngine)
2. **Error Isolation**: NIF crashes should not bring down the entire application
3. **Performance Optimization**: Template compilation caching with intelligent invalidation
4. **Backward Compatibility**: New Typst renderer should coexist with existing renderers

**Risk Mitigation Strategies**:
- Comprehensive error handling for all NIF interactions
- Fallback to existing ChromicPDF if Typst compilation fails
- Template validation before compilation
- Memory usage monitoring and limits

## Technical Details

### File Structure
```
lib/ash_reports/typst/
├── binary_wrapper.ex        # Direct NIF interface
├── template_manager.ex      # Template caching and management
├── band_engine.ex          # Band-to-Typst conversion (Future: Stage 1.3)
└── ash_mapper.ex           # Ash resource mapping (Future: Stage 1.2)

priv/typst_templates/        # Template storage
├── themes/                 # Theme definitions
├── layouts/               # Base layouts
└── examples/              # Example templates

test/ash_reports/typst/     # Comprehensive test suite
├── binary_wrapper_test.exs
├── template_manager_test.exs
└── integration_test.exs
```

### Dependencies to Add
```elixir
# mix.exs additions
{:elixir_typst, "~> 0.1.7"},     # Rust NIF bindings for Typst
{:file_system, "~> 1.0", only: :dev}  # Hot-reloading in development
```

### Configuration
```elixir
# config/config.exs
config :ash_reports, :typst,
  template_dir: "priv/typst_templates",
  cache_enabled: true,
  max_cache_size: 100

# config/dev.exs
config :ash_reports, :typst,
  hot_reload: true,
  template_validation: :strict

# config/runtime.exs
config :ash_reports, :typst,
  binary_path: System.get_env("TYPST_BINARY_PATH"),
  font_paths: System.get_env("FONT_PATHS", "")
```

## Success Criteria

### Functional Requirements
- [ ] **Dependency Integration**: elixir_typst dependency successfully added and compiling
- [ ] **Basic Interface**: Can compile simple Typst template to PDF
- [ ] **Error Handling**: Graceful handling of compilation errors with detailed error messages
- [ ] **Template Management**: File-based template loading with caching
- [ ] **Configuration**: Environment-based configuration working correctly

### Performance Requirements
- [ ] **Speed**: Basic template compilation under 100ms for simple documents
- [ ] **Memory**: Memory usage under 50MB for basic template compilation
- [ ] **Stability**: No BEAM VM crashes during NIF operations
- [ ] **Concurrency**: Support for multiple concurrent compilations

### Quality Requirements
- [ ] **Test Coverage**: 95%+ test coverage for all Typst integration code
- [ ] **Documentation**: Comprehensive documentation with examples
- [ ] **Error Messages**: Clear, actionable error messages for users
- [ ] **Logging**: Proper logging for debugging and monitoring

## Implementation Plan

### Step 1: Environment Setup and Dependencies
**Scope**: Add Typst dependencies and basic configuration
**Files**: `mix.exs`, `config/config.exs`, `lib/ash_reports/application.ex`
**Tests**: Dependency loading and basic configuration tests

**Tasks**:
1.1.1 Add elixir_typst dependency to mix.exs
1.1.2 Configure basic Typst settings in config files
1.1.3 Update application supervision tree
1.1.4 Create priv/typst_templates directory structure
1.1.5 Test dependency compilation and basic functionality

### Step 2: Binary Wrapper Implementation
**Scope**: Create low-level NIF interface wrapper
**Files**: `lib/ash_reports/typst/binary_wrapper.ex`
**Tests**: NIF call testing, error handling validation

**Tasks**:
1.1.6 Implement basic Typst.compile/2 wrapper function
1.1.7 Add error handling for NIF failures and compilation errors
1.1.8 Implement input validation for template strings
1.1.9 Add logging and telemetry for performance monitoring
1.1.10 Create comprehensive unit tests

### Step 3: Template Manager Development
**Scope**: File-based template management with caching
**Files**: `lib/ash_reports/typst/template_manager.ex`
**Tests**: Template loading, caching, and invalidation tests

**Tasks**:
1.1.11 Implement GenServer-based template manager
1.1.12 Add ETS-based template caching with TTL
1.1.13 Implement file-based template loading
1.1.14 Add hot-reloading for development environment
1.1.15 Create template validation and error handling

### Step 4: Integration and Testing
**Scope**: End-to-end integration and comprehensive testing
**Files**: Test suite, integration tests, documentation
**Tests**: Full integration test suite

**Tasks**:
1.1.16 Create integration tests for complete workflow
1.1.17 Add performance benchmarking tests
1.1.18 Implement error scenario testing (NIF crashes, invalid templates)
1.1.19 Create documentation and usage examples
1.1.20 Performance optimization and memory usage validation

## Notes/Considerations

### Edge Cases and Limitations
- **NIF Crashes**: elixir_typst NIF could crash the BEAM VM if poorly handled
- **Template Syntax**: Typst templates use different syntax than current HTML templates
- **Font Dependencies**: Typst requires proper font configuration for various document types
- **Memory Usage**: Large templates can consume significant memory during compilation

### Future Improvements
- **Template Hot-swapping**: Runtime template updates without restart
- **Distributed Compilation**: Multi-node template compilation for scalability
- **Template Analytics**: Usage tracking and performance monitoring
- **Visual Template Editor**: Web-based template editor integration

### Migration Considerations
- **Existing Templates**: Current HTML-based templates need conversion
- **API Compatibility**: New Typst renderer should follow existing renderer interface
- **Gradual Rollout**: Ability to switch between renderers during transition period
- **Performance Comparison**: Benchmarking against existing ChromicPDF implementation

### Dependencies and Risks
- **Rust Toolchain**: Required for compiling elixir_typst during deployment
- **Typst Version**: Need to track Typst language evolution and API changes
- **Font Licensing**: Ensure proper font licensing for commercial document generation
- **Template Security**: Validate templates to prevent code injection vulnerabilities

## Current Status Summary

### What Works
- ✅ **Research Complete**: Comprehensive analysis of Typst integration requirements
- ✅ **Architecture Planned**: Clear module structure and integration points defined
- ✅ **Dependencies Identified**: All required packages and configurations mapped

### What's Next
- 🚧 **Feature Branch Creation**: Create dedicated branch for development
- 🚧 **Dependency Integration**: Add elixir_typst to mix.exs and test compilation
- 🚧 **Basic Implementation**: Create binary wrapper and template manager modules

### How to Run
```bash
# Once implemented, usage will be:
mix deps.get
mix deps.compile
mix test test/ash_reports/typst/

# Development:
iex -S mix
AshReports.Typst.BinaryWrapper.compile("Basic template content", %{format: :pdf})
```

**Priority**: HIGH - Foundation for entire Typst refactor project
**Complexity**: MEDIUM - NIF integration requires careful error handling
**Risk**: LOW - Additive change, existing functionality preserved