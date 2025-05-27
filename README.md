# AshReports

A comprehensive reporting extension for the Ash Framework that provides declarative report definitions with hierarchical band structures, multiple output formats, and internationalization support.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ash_reports` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_reports, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_reports>.

## Implementation Roadmap

### Phase 1: Core Foundation and DSL Framework
- **1.1 Spark DSL Foundation** - Core extension module and DSL schema
- **1.2 Band Hierarchy Implementation** - Band types, ordering, and nesting
- **1.3 Element System** - Field, label, expression, and visual elements
- **1.4 Basic Report Registry** - Report storage and retrieval

### Phase 2: Data Integration and Query System
- **2.1 Query Builder** - Ash query generation with parameters
- **2.2 Variable System Implementation** - Calculations and state management
- **2.3 Group Processing Engine** - Multi-level grouping and breaks
- **2.4 Data Loader** - Streaming and batch data loading

### Phase 3: Rendering Engine and Output Formats
- **3.1 Renderer Interface** - Common rendering behavior and context
- **3.2 HTML Renderer** - Web-based report output
- **3.3 HEEX Renderer** - LiveView integration
- **3.4 PDF Renderer** - Print-ready documents
- **3.5 JSON Renderer** - Structured data export

### Phase 4: Internationalization and Formatting
- **4.1 CLDR Integration** - Locale-aware formatting
- **4.2 Format Specifications** - Number, date, and currency formats
- **4.3 Locale-aware Rendering** - RTL support and translations

### Phase 5: Server Infrastructure
- **5.1 Report Server** - GenServer for report management
- **5.2 Caching System** - ETS-based result caching
- **5.3 MCP Server Implementation** - LLM integration protocol
- **5.4 API Documentation** - Public API and examples

### Phase 6: Advanced Features and Polish
- **6.1 Ash.Resource.Reportable Extension** - Resource-level reporting
- **6.2 Performance Optimization** - Query and rendering optimization
- **6.3 Security Enhancements** - Row-level security and audit trails
- **6.4 Monitoring and Observability** - Telemetry and metrics

