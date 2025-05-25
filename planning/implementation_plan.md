# AshReports Implementation Plan

This document outlines a detailed phased implementation plan for the AshReports extension based on the system design document. Each phase includes specific deliverables, unit tests, and integration tests before proceeding to the next phase.

## Phase 1: Foundation & Core DSL Infrastructure

### Objectives
- Set up the basic project structure and dependencies
- Implement core DSL entity definitions (Report, Band, Column)
- Create basic Spark DSL extension skeleton
- Establish testing infrastructure

### Deliverables

#### 1.1 Project Setup
- [ ] Update `mix.exs` with required dependencies (Spark, Ash, ChromicPDF)
- [ ] Configure application structure in `config/config.exs`
- [ ] Set up basic directory structure under `lib/ash_reports/`

#### 1.2 Core DSL Entities
- [ ] Implement `AshReports.Dsl.Report` struct
- [ ] Implement `AshReports.Dsl.Band` struct  
- [ ] Implement `AshReports.Dsl.Column` struct
- [ ] Create entity definitions for Spark DSL integration

#### 1.3 Basic Extension Modules
- [ ] Create `AshReports.Domain` extension skeleton
- [ ] Create `AshReports.Resource` extension skeleton
- [ ] Implement basic section definitions

### Tests

#### Unit Tests (Phase 1)
- [ ] Test Report struct creation and validation
- [ ] Test Band struct creation and validation
- [ ] Test Column struct creation and validation
- [ ] Test entity definition schemas
- [ ] Test extension module loading

#### Integration Tests (Phase 1)
- [ ] Test domain extension can be loaded by Ash.Domain
- [ ] Test resource extension can be loaded by Ash.Resource
- [ ] Test basic DSL syntax parsing (empty sections)
- [ ] Test extension registration with Spark

**Phase 1 Exit Criteria:** All unit and integration tests pass. Extensions can be loaded without errors. Basic DSL syntax is recognized.

---

## Phase 2: DSL Parsing & Validation

### Objectives
- Implement complete DSL section definitions
- Add DSL entity parsing and validation
- Implement recursive band structure support
- Create comprehensive validation logic

### Deliverables

#### 2.1 Section Definitions
- [ ] Complete `@reports_section` implementation with full schema
- [ ] Complete `@reportable_section` implementation with full schema
- [ ] Add validation rules for section configuration

#### 2.2 Entity Definitions
- [ ] Complete `@column` entity with full schema and validation
- [ ] Complete `@band` entity with recursive support
- [ ] Complete `@report` entity with all options
- [ ] Implement entity cross-validation logic

#### 2.3 Recursive Structure Support
- [ ] Implement recursive band parsing (`recursive_as: :sub_bands`)
- [ ] Add validation for band hierarchy (prevent infinite recursion)
- [ ] Support nested column definitions within bands

#### 2.4 Validation Logic
- [ ] Validate report names are unique within domain
- [ ] Validate band types and nesting rules
- [ ] Validate column field references
- [ ] Validate format specifications

### Tests

#### Unit Tests (Phase 2)
- [ ] Test section schema validation
- [ ] Test entity creation with valid parameters
- [ ] Test entity validation with invalid parameters
- [ ] Test recursive band structure parsing
- [ ] Test band hierarchy validation
- [ ] Test column field validation
- [ ] Test format specification validation

#### Integration Tests (Phase 2)
- [ ] Test complete report definition parsing
- [ ] Test complex nested band structures
- [ ] Test validation error reporting
- [ ] Test DSL compilation with various report configurations
- [ ] Test cross-entity validation (band referencing non-existent columns)

**Phase 2 Exit Criteria:** All DSL syntax is properly parsed and validated. Complex nested reports can be defined. Validation errors are clearly reported.

---

## Phase 3: Transformer Infrastructure

### Objectives
- Implement core transformer framework
- Create report registration transformer
- Implement query generation logic
- Add data binding infrastructure

### Deliverables

#### 3.1 Base Transformer Framework
- [ ] Create `AshReports.Transformers.Base` module
- [ ] Implement transformer error handling
- [ ] Add transformer debugging utilities

#### 3.2 Report Registration Transformer
- [ ] Implement `AshReports.Transformers.RegisterReports`
- [ ] Register reports in domain compile-time state
- [ ] Create report lookup utilities

#### 3.3 Query Generation
- [ ] Implement `AshReports.QueryGenerator` module
- [ ] Add base query building logic
- [ ] Implement filter application from parameters
- [ ] Add relationship loading logic
- [ ] Implement aggregation logic

#### 3.4 Data Binding
- [ ] Create `AshReports.DataBinder` module
- [ ] Implement band data extraction
- [ ] Add parameter interpolation
- [ ] Create data validation logic

### Tests

#### Unit Tests (Phase 3)
- [ ] Test transformer registration
- [ ] Test report registration transformer
- [ ] Test query generation with basic filters
- [ ] Test query generation with relationships
- [ ] Test query generation with aggregations
- [ ] Test data binding to band structures
- [ ] Test parameter interpolation

#### Integration Tests (Phase 3)
- [ ] Test complete transformer pipeline execution
- [ ] Test report registration across multiple domains
- [ ] Test query generation with complex report definitions
- [ ] Test data binding with nested band structures
- [ ] Test end-to-end transformation from DSL to runtime state

**Phase 3 Exit Criteria:** Transformers successfully process DSL definitions into runtime state. Queries can be generated from report definitions. Data can be bound to band structures.

---

## Phase 4: Code Generation & Module Creation

### Objectives
- Implement report module generation transformer
- Create runtime report modules
- Add format-specific module generation
- Implement base report functionality

### Deliverables

#### 4.1 Module Generation Transformer
- [ ] Implement `AshReports.Transformers.GenerateReportModules`
- [ ] Create base report module generation
- [ ] Add format-specific module generation
- [ ] Implement module compilation and evaluation

#### 4.2 Base Report Module
- [ ] Create report module template
- [ ] Implement `generate/2` function
- [ ] Add `get_data/1` function
- [ ] Implement report metadata access

#### 4.3 Format Module Templates
- [ ] Create HTML format module template
- [ ] Create PDF format module template  
- [ ] Create HEEX format module template
- [ ] Add format selection logic

#### 4.4 Runtime Module Integration
- [ ] Implement module loading and caching
- [ ] Add module recompilation on DSL changes
- [ ] Create module introspection utilities

### Tests

#### Unit Tests (Phase 4)
- [ ] Test report module generation
- [ ] Test format module generation
- [ ] Test module compilation
- [ ] Test generated module functionality
- [ ] Test module metadata access
- [ ] Test format selection logic

#### Integration Tests (Phase 4)
- [ ] Test complete module generation pipeline
- [ ] Test generated modules can be called
- [ ] Test module recompilation on changes
- [ ] Test format modules work independently
- [ ] Test runtime module integration with domain

**Phase 4 Exit Criteria:** Report modules are successfully generated and can be called at runtime. Format-specific modules are created correctly. Module recompilation works on DSL changes.

---

## Phase 5: HTML Renderer Implementation

### Objectives
- Implement complete HTML rendering engine
- Create band processing logic
- Add styling and formatting
- Support recursive band rendering

### Deliverables

#### 5.1 HTML Renderer Core
- [ ] Implement `AshReports.Renderers.Html` module
- [ ] Create main `render/3` function
- [ ] Add HTML document structure generation
- [ ] Implement CSS styling integration

#### 5.2 Band Processing
- [ ] Implement `AshReports.Dsl.BandProcessor` module
- [ ] Create recursive band processing logic
- [ ] Add band-specific rendering functions
- [ ] Implement sub-band rendering

#### 5.3 Column Rendering
- [ ] Implement column header generation
- [ ] Create data cell rendering
- [ ] Add column formatting logic
- [ ] Implement column alignment and styling

#### 5.4 Data Formatting
- [ ] Implement value formatting functions
- [ ] Add currency formatting
- [ ] Add percentage formatting
- [ ] Add date/datetime formatting
- [ ] Support custom formatting functions

### Tests

#### Unit Tests (Phase 5)
- [ ] Test HTML document generation
- [ ] Test individual band rendering
- [ ] Test column header generation
- [ ] Test data cell rendering
- [ ] Test recursive band processing
- [ ] Test value formatting functions
- [ ] Test CSS styling application

#### Integration Tests (Phase 5)
- [ ] Test complete HTML report generation
- [ ] Test complex nested band structures in HTML
- [ ] Test various data types and formatting
- [ ] Test report styling and customization
- [ ] Test HTML output validation (valid HTML5)

**Phase 5 Exit Criteria:** HTML reports can be generated from any valid report definition. Output is valid HTML5. All formatting options work correctly.

---

## Phase 6: PDF & HEEX Renderers

### Objectives
- Implement PDF rendering via ChromicPDF
- Create HEEX template renderer
- Add format-specific optimizations
- Implement format conversion pipeline

### Deliverables

#### 6.1 PDF Renderer
- [ ] Implement `AshReports.Renderers.Pdf` module
- [ ] Integrate ChromicPDF for HTML-to-PDF conversion
- [ ] Add PDF-specific styling optimizations
- [ ] Implement PDF output options (page size, margins)

#### 6.2 HEEX Renderer
- [ ] Implement `AshReports.Renderers.Heex` module
- [ ] Create HEEX template generation
- [ ] Add Phoenix LiveView integration
- [ ] Implement component-based rendering

#### 6.3 Format Pipeline
- [ ] Create format conversion utilities
- [ ] Add format-specific optimizations
- [ ] Implement format validation
- [ ] Add format-specific error handling

#### 6.4 Advanced Features
- [ ] Add page break handling for PDF
- [ ] Implement print-friendly CSS for PDF
- [ ] Add interactive features for HEEX
- [ ] Support format-specific options

### Tests

#### Unit Tests (Phase 6)
- [ ] Test PDF generation from HTML
- [ ] Test HEEX template generation
- [ ] Test format conversion utilities
- [ ] Test PDF styling and options
- [ ] Test HEEX component rendering
- [ ] Test format-specific error handling

#### Integration Tests (Phase 6)
- [ ] Test complete PDF report generation
- [ ] Test complete HEEX report generation
- [ ] Test format switching for same report
- [ ] Test PDF output quality and formatting
- [ ] Test HEEX integration with Phoenix
- [ ] Test format-specific features (page breaks, interactivity)

**Phase 6 Exit Criteria:** PDF and HEEX formats work correctly. All three formats (HTML, PDF, HEEX) can be generated from the same report definition. Format-specific features function properly.

---

## Phase 7: Resource Actions & Integration

### Objectives
- Implement resource action transformers
- Add report actions to resources
- Create domain-level report management
- Implement runtime report execution

### Deliverables

#### 7.1 Resource Action Transformer
- [ ] Implement `AshReports.Transformers.AddReportActions`
- [ ] Add report generation actions to resources
- [ ] Create action parameter handling
- [ ] Implement action authorization

#### 7.2 Domain Integration
- [ ] Add domain-level report registry
- [ ] Implement report discovery utilities
- [ ] Create domain report management functions
- [ ] Add cross-resource report support

#### 7.3 Runtime Execution
- [ ] Implement report execution pipeline
- [ ] Add parameter validation and processing
- [ ] Create error handling and reporting
- [ ] Implement result caching

#### 7.4 API Integration
- [ ] Add report endpoints to resources
- [ ] Implement report parameter parsing
- [ ] Create report result serialization
- [ ] Add format content-type handling

### Tests

#### Unit Tests (Phase 7)
- [ ] Test resource action generation
- [ ] Test action parameter handling
- [ ] Test domain report registry
- [ ] Test report execution pipeline
- [ ] Test parameter validation
- [ ] Test error handling
- [ ] Test result caching

#### Integration Tests (Phase 7)
- [ ] Test resource actions in complete Ash application
- [ ] Test domain-level report management
- [ ] Test cross-resource report execution
- [ ] Test API endpoint functionality
- [ ] Test authorization and security
- [ ] Test end-to-end report generation from API calls

**Phase 7 Exit Criteria:** Reports can be executed through resource actions and API endpoints. Domain-level report management works. Security and authorization are properly implemented.

---

## Phase 8: Advanced Features & Optimization

### Objectives
- Implement caching and performance optimization
- Add advanced report features
- Create report debugging tools
- Implement report scheduling

### Deliverables

#### 8.1 Caching & Performance
- [ ] Implement report result caching
- [ ] Add query optimization
- [ ] Create memory usage optimization
- [ ] Implement streaming for large reports

#### 8.2 Advanced Features
- [ ] Add conditional band rendering
- [ ] Implement calculated fields
- [ ] Create report parameters with defaults
- [ ] Add report composition (sub-reports)

#### 8.3 Debugging & Development Tools
- [ ] Create report DSL validation tools
- [ ] Add report generation debugging
- [ ] Implement performance profiling
- [ ] Create report testing utilities

#### 8.4 Scheduling & Automation
- [ ] Add scheduled report generation
- [ ] Implement report delivery (email, file system)
- [ ] Create report notification system
- [ ] Add report archiving

### Tests

#### Unit Tests (Phase 8)
- [ ] Test caching functionality
- [ ] Test performance optimizations
- [ ] Test advanced report features
- [ ] Test debugging tools
- [ ] Test scheduling system
- [ ] Test delivery mechanisms

#### Integration Tests (Phase 8)
- [ ] Test cached report generation performance
- [ ] Test complex reports with advanced features
- [ ] Test debugging tools with real reports
- [ ] Test scheduled report execution
- [ ] Test complete delivery pipeline
- [ ] Test system performance under load

**Phase 8 Exit Criteria:** All advanced features work correctly. Performance is optimized for production use. Debugging and development tools are functional. Scheduling and delivery systems work reliably.

---

## Phase 9: Internal Report Server

### Objectives
- Create a dedicated report server process
- Implement report generation queuing and processing
- Add server-side caching and management
- Support distributed report generation

### Deliverables

#### 9.1 Report Server Core
- [ ] Implement `AshReports.Server` GenServer module
- [ ] Create server startup and configuration
- [ ] Add server state management
- [ ] Implement graceful shutdown handling

#### 9.2 Job Queue System
- [ ] Implement `AshReports.Queue` module
- [ ] Create job queuing for report generation
- [ ] Add job priority and scheduling
- [ ] Implement job retry logic and error handling

#### 9.3 Server-Side Caching
- [ ] Create `AshReports.Cache` module
- [ ] Implement report result caching
- [ ] Add cache invalidation strategies
- [ ] Support distributed caching (via ETS/Mnesia)

#### 9.4 Worker Pool Management
- [ ] Implement `AshReports.WorkerPool` module
- [ ] Create configurable worker pool sizes
- [ ] Add worker health monitoring
- [ ] Implement load balancing across workers

#### 9.5 Server API
- [ ] Create server client API module
- [ ] Implement async report generation requests
- [ ] Add report status checking
- [ ] Support report result retrieval

#### 9.6 Monitoring & Metrics
- [ ] Add server performance metrics
- [ ] Implement job queue monitoring
- [ ] Create health check endpoints
- [ ] Add logging and debugging tools

### Tests

#### Unit Tests (Phase 9)
- [ ] Test server startup and shutdown
- [ ] Test job queue operations
- [ ] Test caching functionality
- [ ] Test worker pool management
- [ ] Test server API functions
- [ ] Test error handling and recovery

#### Integration Tests (Phase 9)
- [ ] Test complete server workflow
- [ ] Test concurrent report generation
- [ ] Test server under load
- [ ] Test distributed caching
- [ ] Test worker failure scenarios
- [ ] Test server restart and state recovery

**Phase 9 Exit Criteria:** Report server handles concurrent requests efficiently. Queue system processes jobs reliably. Caching improves performance. Worker pool scales appropriately. Server API works correctly.

---

## Phase 10: MCP Server Integration

### Objectives
- Create Model Context Protocol (MCP) server for reports
- Implement MCP tools for report management
- Add report generation and discovery via MCP
- Support remote report execution through MCP

### Deliverables

#### 10.1 MCP Server Core
- [ ] Implement `AshReports.McpServer` module
- [ ] Create MCP server initialization and configuration
- [ ] Add MCP protocol message handling
- [ ] Implement server capability registration

#### 10.2 MCP Tools Implementation
- [ ] Create `list_reports` tool for report discovery
- [ ] Implement `generate_report` tool for report execution
- [ ] Add `get_report_schema` tool for report structure inspection
- [ ] Create `get_report_status` tool for async generation monitoring

#### 10.3 Report Discovery Tools
- [ ] Implement domain report enumeration
- [ ] Add report metadata exposure
- [ ] Create report parameter schema generation
- [ ] Support format capability discovery

#### 10.4 Report Generation Tools
- [ ] Implement synchronous report generation
- [ ] Add asynchronous report generation with status tracking
- [ ] Create report result retrieval
- [ ] Support multiple output formats via MCP

#### 10.5 MCP Resource Management
- [ ] Implement report result resource exposure
- [ ] Add report template resource access
- [ ] Create report history and caching resources
- [ ] Support report asset management (images, CSS)

#### 10.6 Authentication & Security
- [ ] Implement MCP authentication mechanisms
- [ ] Add report access authorization
- [ ] Create secure parameter handling
- [ ] Implement audit logging for MCP operations

### Tests

#### Unit Tests (Phase 10)
- [ ] Test MCP server initialization
- [ ] Test MCP tool registration and discovery
- [ ] Test report listing functionality
- [ ] Test report generation tools
- [ ] Test schema generation and validation
- [ ] Test authentication and authorization
- [ ] Test error handling and responses

#### Integration Tests (Phase 10)
- [ ] Test complete MCP client-server workflow
- [ ] Test report generation through MCP protocol
- [ ] Test multi-client concurrent access
- [ ] Test MCP server integration with internal report server
- [ ] Test resource management and retrieval
- [ ] Test authentication across different clients
- [ ] Test error propagation and handling

**Phase 10 Exit Criteria:** MCP server responds to all protocol messages correctly. Report tools work through MCP interface. Authentication and security are properly implemented. Multiple clients can access reports concurrently.

---

## Phase 11: Documentation & Examples

### Objectives
- Create comprehensive documentation
- Build example applications
- Write tutorials and guides
- Prepare for release

### Deliverables

#### 10.1 API Documentation
- [ ] Document all public modules and functions
- [ ] Create DSL reference documentation
- [ ] Add configuration option documentation
- [ ] Document format-specific features

#### 10.2 User Guides
- [ ] Write getting started guide
- [ ] Create DSL tutorial
- [ ] Add advanced features guide
- [ ] Write performance optimization guide

#### 10.3 Example Applications
- [ ] Create basic report example
- [ ] Build complex nested report example
- [ ] Add format-specific examples
- [ ] Create real-world use case examples

#### 10.4 Developer Documentation
- [ ] Document extension architecture
- [ ] Add transformer development guide
- [ ] Create renderer development guide
- [ ] Write testing best practices

### Tests

#### Unit Tests (Phase 10)
- [ ] Test all example code compiles
- [ ] Test tutorial code snippets
- [ ] Validate documentation examples
- [ ] Test getting started guide

#### Integration Tests (Phase 10)
- [ ] Test complete example applications
- [ ] Validate tutorial workflows
- [ ] Test documentation accuracy
- [ ] Verify all features are documented

**Phase 11 Exit Criteria:** Documentation is complete and accurate. Example applications demonstrate all features. Getting started guide works for new users. Developer documentation supports extension development.

---

## Phase 12: Testing & Release Preparation

### Objectives
- Comprehensive testing across all features
- Performance testing and optimization
- Security audit and hardening
- Release preparation

### Deliverables

#### 12.1 Comprehensive Testing
- [ ] Execute full test suite
- [ ] Add missing test coverage
- [ ] Test across Elixir/OTP versions
- [ ] Test integration with different Ash versions

#### 12.2 Performance Testing
- [ ] Benchmark report generation performance
- [ ] Test memory usage with large datasets
- [ ] Optimize query generation
- [ ] Test concurrent report generation

#### 12.3 Security Audit
- [ ] Review input validation
- [ ] Test authorization mechanisms  
- [ ] Audit file system access
- [ ] Review dependency security

#### 12.4 Release Preparation
- [ ] Finalize version numbers
- [ ] Update changelog
- [ ] Prepare release notes
- [ ] Tag release version

### Tests

#### Unit Tests (Phase 12)
- [ ] 100% test coverage on critical paths
- [ ] Security test cases
- [ ] Performance regression tests
- [ ] Cross-version compatibility tests

#### Integration Tests (Phase 12)
- [ ] Full end-to-end test scenarios
- [ ] Load testing with large reports
- [ ] Security penetration testing
- [ ] Real-world application testing

**Phase 12 Exit Criteria:** All tests pass consistently. Performance meets requirements. Security audit passes. Release is ready for production use.

---

## Testing Strategy

### Test Categories

1. **Unit Tests**: Test individual modules and functions in isolation
2. **Integration Tests**: Test component interactions and full workflows
3. **End-to-End Tests**: Test complete user scenarios from DSL to output
4. **Performance Tests**: Test system performance under various loads
5. **Security Tests**: Test authorization, validation, and security mechanisms

### Test Tools

- **ExUnit**: Primary testing framework
- **Mox**: Mocking and testing doubles
- **Bypass**: HTTP endpoint testing
- **Benchee**: Performance benchmarking
- **Credo**: Code quality and consistency
- **Dialyzer**: Static analysis and type checking

### Continuous Integration

Each phase must pass all tests before proceeding to the next phase. Integration tests from previous phases must continue to pass as new features are added.

## Dependencies

### Phase Dependencies
- Phase 2 depends on Phase 1 completion
- Phase 3 depends on Phase 2 completion
- Phase 4 depends on Phase 3 completion
- Phases 5 and 6 can be developed in parallel after Phase 4
- Phase 7 depends on completion of Phases 5 and 6
- Phase 8 depends on Phase 7 completion
- Phase 9 depends on Phase 8 completion
- Phase 10 depends on Phase 9 completion (MCP server needs internal server)
- Phases 11 and 12 can begin after Phase 10

### External Dependencies
- Elixir 1.14+
- Ash Framework 3.0+
- Spark DSL 2.0+
- ChromicPDF (for PDF generation)
- Phoenix (for HEEX rendering)
- Poolboy or similar (for worker pool management)
- ETS/Mnesia (for distributed caching)
- MCP protocol library (for Model Context Protocol support)
- JSON-RPC 2.0 library (for MCP communication)

## Success Criteria

### Functional Requirements
- [ ] Complete DSL for report definition
- [ ] Support for HTML, PDF, and HEEX output formats
- [ ] Recursive band structures with arbitrary nesting
- [ ] Integration with Ash domains and resources
- [ ] Query generation from report definitions
- [ ] Formatting and styling support
- [ ] Internal report server with queuing and caching
- [ ] MCP server for remote report access and management

### Non-Functional Requirements
- [ ] Performance: Generate reports with 10,000+ records in under 30 seconds
- [ ] Memory: Handle large datasets without excessive memory usage
- [ ] Security: Proper authorization and input validation
- [ ] Maintainability: Clean, well-documented, testable code
- [ ] Compatibility: Works with current Ash ecosystem versions
- [ ] Scalability: Handle concurrent report generation requests
- [ ] Reliability: Server resilience and fault tolerance
- [ ] Interoperability: MCP protocol compliance and client compatibility

## Risk Mitigation

### Technical Risks
- **Complex DSL parsing**: Mitigated by comprehensive testing in Phase 2
- **Performance with large datasets**: Addressed by optimization in Phase 8
- **PDF generation reliability**: Tested thoroughly in Phase 6
- **Memory usage**: Monitored and optimized throughout development
- **Server scalability**: Addressed by worker pool and queue system in Phase 9
- **Concurrent access**: Mitigated by proper caching and state management
- **MCP protocol compliance**: Addressed by comprehensive protocol testing in Phase 10
- **Remote access security**: Mitigated by proper authentication and authorization in MCP server

### Project Risks
- **Scope creep**: Controlled by strict phase boundaries and exit criteria
- **Integration issues**: Prevented by integration tests at each phase
- **Ash framework changes**: Mitigated by version compatibility testing
- **Performance requirements**: Addressed by dedicated performance testing phase

This implementation plan provides a structured approach to building the AshReports extension with clear deliverables, comprehensive testing, and risk mitigation at each phase.