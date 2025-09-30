# AshReports Typst Integration Refactor Implementation Plan

## 📋 Overview

This plan implements a complete architectural refactor of AshReports to replace the current rendering system with a modern Typst-based engine. The refactor leverages Typst's **18x faster compilation speed**, native multi-format output support, and seamless integration with Elixir's concurrent processing capabilities.

**Current Status**: AshReports has a complete Spark DSL framework with band-based report definitions, but needs modern Typst integration for performance.

**Target Architecture**: DSL-driven Typst template generation → 18x faster compilation → Modern multi-format output (PDF, PNG, SVG)

**Key Architectural Insight**: Generate Typst templates dynamically from AshReports DSL definitions rather than managing static template files.

---

# Stage 1: Infrastructure Foundation and Typst Integration

**Duration**: 2-3 weeks
**Status**: ✅ **COMPLETED** - Sections 1.1, 1.2, 1.3 Complete
**Goal**: Establish core Typst integration infrastructure and replace basic rendering pipeline

## 1.1 Typst Runtime Integration

### 1.1.1 Elixir Typst Bindings Setup
- [x] Add Typst Elixir bindings dependency (typst 0.1.7) - **COMPLETED**
- [x] Configure Rustler for Typst compilation integration - **COMPLETED**
- [x] Implement basic Typst rendering interface - **COMPLETED**
- [x] Create Typst binary wrapper module - **COMPLETED**
- [x] Add error handling for Typst compilation failures - **COMPLETED**

### 1.1.2 ~~Template Engine Foundation~~ → **ARCHITECTURAL PIVOT**
- [x] ~~Create `AshReports.Typst.TemplateManager` module~~ - **REPLACED with DSL-driven approach**
- [x] ~~Implement file-based template system~~ - **PIVOTED to DSL-to-Typst generation**
- [x] Add template caching with ETS - **REUSED in new architecture**
- [x] Create hot-reloading for development environment - **REUSED for generated templates**
- [x] Implement template validation and compilation checking - **REUSED with BinaryWrapper**

**🔄 ARCHITECTURAL DECISION**: Pivot from manual template files to DSL-driven template generation.
AshReports should generate Typst templates dynamically from Spark DSL report definitions, not load static `.typ` files.

## 1.2 DSL-to-Typst Template Generation **← COMPLETED** ✅

### 1.2.1 DSL Template Generator
- [x] Create `AshReports.Typst.DSLGenerator` module - **COMPLETED**
- [x] Implement AshReports DSL → Typst template conversion - **COMPLETED**
- [x] Map band types (title, header, detail, footer) to Typst structures - **COMPLETED**
- [x] Generate conditional sections and grouping logic - **COMPLETED**
- [x] Support element types (field, label, expression, aggregate, line, box, image) - **COMPLETED**

### 1.2.2 Band Architecture Implementation
- [x] Implement Crystal Reports-style band rendering in Typst - **COMPLETED**
- [x] Create hierarchical band processing (nested groups) - **COMPLETED**
- [x] Add support for band positioning and layout - **COMPLETED**
- [x] Implement page break and section flow control - **COMPLETED**
- [x] Create band-specific styling and theming - **COMPLETED**

### 1.2.3 Element Rendering System
- [x] Map AshReports elements to Typst components: - **COMPLETED**
  - `field` → Data field display with formatting
  - `label` → Static text with positioning
  - `expression` → Calculated expressions
  - `aggregate` → Sum, count, avg functions
  - `line` → Graphical separators
  - `box` → Container elements
  - `image` → Image embedding

## 1.3 Ash Resource Data Integration **← COMPLETED** ✅

### 1.3.1 Query to Data Pipeline
- [x] Create `AshReports.Typst.DataLoader` module - **COMPLETED**
- [x] Implement driving_resource query execution - **COMPLETED**
- [x] Handle resource relationships and preloading - **COMPLETED**
- [x] Transform Ash structs to Typst-compatible data - **COMPLETED**
- [x] Support calculated fields and aggregations - **COMPLETED**

### 1.3.2 Data Formatting and Processing
- [x] Implement data type conversion (DateTime, Decimal, Money) - **COMPLETED**
- [x] Create grouping and sorting based on DSL definitions - **COMPLETED**
- [x] Add support for complex relationship traversal - **COMPLETED**
- [x] Implement variable scopes (detail, group, page, report) - **COMPLETED**
- [ ] Handle large dataset streaming with GenStage - **See Section 2.4 for implementation**

## 1.4 Integration Testing Infrastructure

### 1.4.1 Test Framework Setup
- [ ] Create Typst rendering test helpers
- [ ] Add performance benchmarking for compilation speed
- [ ] Implement visual regression testing for PDF output
- [ ] Create mock data generators for complex scenarios
- [ ] Add memory usage monitoring for large reports

---

# Stage 2: Performance Optimization and Visualization

**Duration**: 3-4 weeks
**Status**: 📋 Planned
**Goal**: Implement D3.js chart integration, GenStage streaming for large datasets, and comprehensive performance optimization

## 2.1 D3 Rendering Service

### 2.1.1 Node.js Service Development
- [ ] Create standalone Node.js D3 rendering service
- [ ] Implement chart type abstraction (bar, line, pie, heatmap)
- [ ] Add SVG optimization and compression
- [ ] Create chart configuration schema
- [ ] Implement error handling and fallback generation

### 2.1.2 Service Integration
- [ ] Create `AshReports.Typst.D3Client` module
- [ ] Implement HTTP client for D3 service communication
- [ ] Add connection pooling and health checking
- [ ] Create chart caching system
- [ ] Implement service failover mechanisms

## 2.2 Chart Data Processing

### 2.2.1 Data Transformation Pipeline
- [ ] Create chart data extraction from Ash resources
- [ ] Implement aggregation functions for visualization
- [ ] Add support for time-series data formatting
- [ ] Create multi-dimensional data pivoting
- [ ] Implement statistical calculations for charts
- [ ] Integrate with GenStage streaming for large dataset aggregation (see Section 2.4)

**Note**: For datasets >10K records, use GenStage streaming pipeline (Section 2.4) to perform server-side aggregation before sending to D3 rendering service. This is essential for performance - D3.js can render ~5,000 SVG elements or ~50,000 canvas points efficiently, so large datasets must be aggregated server-side first.

### 2.2.2 Dynamic Chart Generation
- [ ] Add runtime chart configuration from DSL
- [ ] Implement conditional chart rendering
- [ ] Create chart theming system
- [ ] Add interactive chart options
- [ ] Implement chart export functionality

## 2.3 Typst Chart Integration

### 2.3.1 SVG Embedding System
- [ ] Create SVG-to-Typst conversion helpers
- [ ] Implement chart positioning and layout
- [ ] Add caption and legend support
- [ ] Create multi-chart page layouts
- [ ] Implement chart scaling and responsiveness

### 2.3.2 Performance Optimization
- [ ] Add parallel chart generation
- [ ] Implement chart result caching
- [ ] Create lazy loading for complex visualizations
- [ ] Add compression for embedded SVG data
- [ ] Implement memory-efficient chart processing

## 2.4 GenStage Streaming Pipeline for Large Datasets

**Goal**: Implement memory-efficient streaming for reports with 10K+ records using GenStage/Flow

**Use Cases**:
- Full report generation with 100K+ records
- D3 chart data aggregation (see Section 2.2.1) - stream 1M records → aggregate to 500 chart datapoints
- Real-time report updates with incremental data loading
- Memory-efficient export for large datasets

### 2.4.1 GenStage Infrastructure Setup
- [ ] Add gen_stage dependency to mix.exs (~> 1.2)
- [ ] Add flow dependency to mix.exs (~> 1.2)
- [ ] Create `AshReports.Typst.StreamingPipeline` module
- [ ] Design producer-consumer architecture
- [ ] Implement supervision tree for streaming processes

### 2.4.2 Producer Implementation
- [ ] Create `StreamingProducer` for chunked Ash query execution
- [ ] Implement demand-driven query batching
- [ ] Add intelligent preloading for relationships
- [ ] Handle query pagination with Ash offset/limit
- [ ] Implement memory monitoring and circuit breakers

### 2.4.3 Consumer/Transformer Implementation
- [ ] Create `StreamingConsumer` for data transformation
- [ ] Integrate with DataProcessor for type conversion
- [ ] Implement streaming aggregation functions (sum, count, avg, percentiles)
- [ ] Add support for time-series bucketing and grouping (for D3 charts)
- [ ] Implement backpressure handling
- [ ] Add progress tracking and telemetry
- [ ] Create configurable buffer management

### 2.4.4 DataLoader Integration
- [ ] Implement `create_streaming_pipeline/4` function in DataLoader
- [ ] Replace error placeholder with actual GenStage pipeline
- [ ] Add streaming configuration options
- [ ] Implement stream cancellation support
- [ ] Create automatic fallback for small datasets (<10K records)

### 2.4.5 Testing and Performance Validation
- [ ] Create streaming pipeline unit tests
- [ ] Add memory usage benchmarks (target: <1.5x baseline)
- [ ] Test with datasets of 10K, 100K, 1M records
- [ ] Validate throughput (target: 1000+ records/sec)
- [ ] Test cancellation and error recovery

**Performance Targets**:
- **Memory Usage**: <1.5x baseline regardless of dataset size
- **Throughput**: 1000+ records/second on standard hardware
- **Scalability**: Support datasets from 10K to 1M+ records
- **Latency**: Streaming should start within 100ms
- **Reliability**: Automatic fallback to batch loading on errors

**Architecture Overview**:
```
Ash Query → StreamingProducer (chunks of 500-1000 records)
                ↓
         GenStage backpressure
                ↓
      StreamingConsumer (DataProcessor transformation)
                ↓
         Enumerable Stream → Typst Compilation
```

---

# Stage 3: Phoenix LiveView Integration and Real-time Features

**Duration**: 2-3 weeks
**Status**: 📋 Planned
**Goal**: Create modern web interface with real-time report generation

## 3.1 LiveView Report Builder

### 3.1.1 Interactive Report Designer
- [ ] Create `AshReportsWeb.ReportBuilderLive` module
- [ ] Implement template selection interface
- [ ] Add drag-and-drop data source configuration
- [ ] Create real-time preview system
- [ ] Implement collaborative editing features

### 3.1.2 Progress Tracking System
- [ ] Add real-time generation progress bars
- [ ] Implement WebSocket-based status updates
- [ ] Create task management for background jobs
- [ ] Add cancellation support for long-running reports
- [ ] Implement notification system for completion

## 3.2 Advanced UI Components

### 3.2.1 Data Configuration Interface
- [ ] Create data source selection components
- [ ] Implement filter and parameter configuration
- [ ] Add preview data sampling
- [ ] Create relationship mapping tools
- [ ] Implement validation and error display

### 3.2.2 Template Customization
- [ ] Add theme selection interface
- [ ] Implement style customization tools
- [ ] Create logo and branding upload
- [ ] Add font selection and preview
- [ ] Implement custom CSS/styling options

## 3.3 Report Gallery and Management

### 3.3.1 Report Library System
- [ ] Create report listing and search
- [ ] Implement tagging and categorization
- [ ] Add sharing and permissions management
- [ ] Create version control for templates
- [ ] Implement report scheduling system

---

# Stage 4: Production Deployment and Scalability

**Duration**: 2-3 weeks
**Status**: 📋 Planned
**Goal**: Production-ready deployment with monitoring and scalability

## 4.1 Containerization and Orchestration

### 4.1.1 Docker Configuration
- [ ] Create multi-stage Dockerfile with Typst, Node.js, and Elixir
- [ ] Implement proper font installation and configuration
- [ ] Add health checks for all services
- [ ] Create volume management for templates and cache
- [ ] Implement security hardening

### 4.1.2 Kubernetes Deployment
- [ ] Create Kubernetes manifests for scalable deployment
- [ ] Implement horizontal pod autoscaling
- [ ] Add persistent volume claims for report storage
- [ ] Create service mesh configuration
- [ ] Implement rolling updates and rollback strategies

## 4.2 Monitoring and Observability

### 4.2.1 Telemetry Implementation
- [ ] Add comprehensive Telemetry metrics
- [ ] Implement Prometheus integration
- [ ] Create custom dashboards for report performance
- [ ] Add alerting for service failures
- [ ] Implement distributed tracing

### 4.2.2 Performance Optimization
- [ ] Create performance benchmarking suite
- [ ] Implement connection pooling optimization
- [ ] Add memory usage monitoring and optimization
- [ ] Create cache warming strategies
- [ ] Implement query optimization for large datasets

## 4.3 Security and Compliance

### 4.3.1 Security Hardening
- [ ] Implement template sandboxing
- [ ] Add input validation and sanitization
- [ ] Create audit logging for report generation
- [ ] Implement rate limiting and DDoS protection
- [ ] Add data encryption for sensitive reports

---

# Stage 5: Migration Tools and Backward Compatibility

**Duration**: 1-2 weeks
**Status**: 📋 Planned
**Goal**: Seamless migration from existing AshReports implementation

## 5.1 Migration Utilities

### 5.1.1 Automated Migration Tools
- [ ] Create DSL compatibility analyzer
- [ ] Implement automatic template conversion
- [ ] Add migration validation and testing
- [ ] Create rollback mechanisms
- [ ] Implement gradual migration support

### 5.1.2 Compatibility Layer
- [ ] Maintain API compatibility for existing reports
- [ ] Create adapter pattern for legacy renderers
- [ ] Implement feature parity checking
- [ ] Add deprecation warnings and migration guides
- [ ] Create side-by-side comparison tools

## 5.2 Documentation and Training

### 5.2.1 Comprehensive Documentation
- [ ] Create migration guide from current system
- [ ] Write Typst template development guide
- [ ] Add performance tuning documentation
- [ ] Create troubleshooting guides
- [ ] Implement interactive tutorials

### 5.2.2 Developer Tools
- [ ] Create Typst template debugging tools
- [ ] Add development environment setup scripts
- [ ] Implement template validation CLI tools
- [ ] Create performance profiling utilities
- [ ] Add automated testing helpers

---

# Integration Testing and Validation

## Performance Targets
- **Small reports (1-10 pages)**: 100-500ms total generation
- **Medium reports (10-100 pages)**: 1-10 seconds
- **Large reports (100-1000 pages)**: 10-60 seconds
- **Memory efficiency**: 50-200MB per report
- **Concurrent processing**: 100+ reports on production hardware

## Quality Assurance
- **Feature parity**: All existing AshReports functionality maintained
- **Performance improvement**: 18x faster compilation vs current system
- **Output quality**: Pixel-perfect PDF generation
- **Reliability**: 99.9% uptime with proper monitoring
- **Developer experience**: Hot-reloading, debugging tools, comprehensive docs

## Success Criteria
- [ ] All existing reports render correctly in Typst system
- [ ] Performance targets met or exceeded
- [ ] Production deployment successful with monitoring
- [ ] Developer migration path validated
- [ ] Full backward compatibility maintained during transition period

---

## Architecture Overview

### Current State Analysis
Based on the research document `ash_reports_typst_research.md`, the current AshReports system has:
- Complete DSL framework with Spark extensions
- Four output renderers (HTML, HEEX, PDF, JSON)
- Band-based report structure
- Variable and grouping systems
- Phoenix LiveView integration

### Target State Benefits
The DSL-driven Typst refactor will provide:
- **18x faster compilation** compared to current PDF generation
- **DSL-driven template generation** from AshReports band definitions
- **Enhanced visualizations** with D3.js server-side rendering
- **Better developer experience** with declarative report definitions
- **Improved scalability** with streaming and concurrent processing
- **Production-ready deployment** with monitoring and observability

### New Workflow Architecture
```
AshReports DSL Definition
    ↓
reports do
  report :sales_report do
    bands do
      band :title do
        elements do
          label :title_label do
            text "Sales Report"
          end
        end
      end
    end
  end
end
    ↓
DSLGenerator.generate_typst_template(report_definition)
    ↓
Generated Typst Template:
#set page(paper: "a4")
= Sales Report
...
    ↓
BinaryWrapper.compile(template, data)
    ↓
PDF Output (18x faster)
```

### Migration Strategy
1. **Parallel Development**: Build Typst system alongside existing renderers
2. **Gradual Migration**: Implement feature parity before deprecating old system
3. **Compatibility Layer**: Maintain API compatibility during transition
4. **Validation Testing**: Comprehensive testing to ensure output quality
5. **Performance Benchmarking**: Validate performance improvements

### Technical Dependencies
- **Typst 0.1.7** (Elixir package): Rust NIF bindings for Typst compilation ✅ **IMPLEMENTED**
- **AshReports DSL System**: Existing Spark DSL extensions for report definitions ✅ **AVAILABLE**
- **Ash Framework 3.0+**: Resource querying and data transformation ✅ **AVAILABLE**
- **Node.js + D3.js**: Server-side chart generation (Stage 2)
- **GenStage/Flow**: Stream processing for large datasets (Stage 1.3)
- **Phoenix LiveView**: Enhanced web interface (Stage 3)

### Risk Mitigation
- **Incremental Implementation**: Stage-based approach reduces risk
- **Fallback Mechanisms**: Maintain existing renderers during transition
- **Comprehensive Testing**: Unit, integration, and performance testing
- **Monitoring**: Full observability for production deployment
- **Documentation**: Complete migration guides and troubleshooting

---

**Total Duration**: 8-11 weeks
**Team Requirements**: 2-3 developers with Elixir, TypeScript, and DevOps experience
**Infrastructure Requirements**: Kubernetes cluster, monitoring stack, CI/CD pipeline

**Next Steps**:
1. **✅ Stage 1.1 COMPLETED**: Typst Runtime Integration with BinaryWrapper
2. **🎯 CURRENT PRIORITY**: Stage 1.2 - DSL-to-Typst Template Generation
3. Implement `AshReports.Typst.DSLGenerator` to convert AshReports DSL → Typst templates
4. Create band-to-Typst mapping for all element types (field, label, expression, etc.)
5. Integrate with Ash resource queries for data loading and transformation

**Architectural Pivot Complete**: From static template files → Dynamic DSL-driven template generation