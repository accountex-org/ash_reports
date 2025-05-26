
## Project Overview

AshReports is an Elixir extension for the Ash Framework that adds comprehensive reporting capabilities to Ash domains. The extension allows for declarative definition of complex hierarchical reports using Spark DSL, with support for multiple output formats (HTML, PDF, HEEX).

## Architecture

This is a **Spark DSL extension** project that integrates with Ash Framework's domain and resource system. The core architecture includes:

- **Domain Extension** - Adds reporting capabilities to Ash.Domain modules
- **Resource Extension** - Adds reportable configuration to Ash.Resource modules  
- **Hierarchical Band Structure** - Supports recursive report bands (header, detail, footer, group bands)
- **Multi-format Output** - Generates reports in HTML, PDF, and HEEX formats
- **Query Integration** - Leverages Ash queries for data fetching and filtering

Key components:
- `AshReports.Dsl` - Core DSL definitions for reports, bands, and columns
- `AshReports.Transformers` - Code generators that create runtime report modules
- `AshReports.Renderers` - Format-specific rendering implementations
- `AshReports.QueryGenerator` - Ash query building for report data

## Dependencies

The project uses these key dependencies:
- `ash ~> 3.0` - Core Ash Framework
- `sourceror ~> 1.8` - Code manipulation (dev/test only)
- `igniter ~> 0.5` - Code generation utilities (dev/test only)

## Development Commands

### Basic Operations
```bash
# Get dependencies
mix deps.get

# Compile the project  
mix compile

# Run tests
mix test

# Format code (uses Spark.Formatter)
mix format

# Run a specific test
mix test test/ash_reports_test.exs
```

### Code Quality
The project uses Spark.Formatter with specific configuration for Ash extensions. The formatter is configured to:
- Remove parentheses where possible
- Order Ash.Resource sections in a specific sequence
- Order Ash.Domain sections appropriately

## Implementation Patterns

### DSL Extension Structure
When working with this codebase, understand that it follows Spark DSL extension patterns:

1. **Entity Definitions** - Structured data (Report, Band, Column)
2. **Section Definitions** - DSL sections (reports, reportable)  
3. **Transformers** - Code generation and structure manipulation at compile time
4. **Verifiers** - DSL validation at compile time
5. **Recursive Entities** - Bands can contain sub-bands with arbitrary nesting

**IMPORTANT: Validation vs Transformation**
- **Transformers** should ONLY be used for code generation, structure manipulation, and compile-time transformations
- **Verifiers** should be used for ALL validation logic including:
  - Checking for duplicate names
  - Validating required fields
  - Ensuring correct relationships between entities
  - Type checking and constraint validation
  - Any logic that validates the correctness of the DSL
- Never put validation logic in Transformers - use Verifiers instead

### Hierarchical Band System Implementation

The system implements a 9-level hierarchical band structure as defined in the system design:

1. **Band Types** (in execution order):
   - `:title` - Report title, appears once at report start
   - `:page_header` - Appears at top of each page
   - `:column_header` - Column headers for data sections
   - `:group_header` - Headers for grouped data (supports multiple levels)
   - `:detail_header` - Optional header before detail rows
   - `:detail` - The actual data rows (supports multiple detail bands)
   - `:detail_footer` - Optional footer after detail rows
   - `:group_footer` - Footers for grouped data (supports multiple levels)
   - `:column_footer` - Column footers for aggregations
   - `:page_footer` - Appears at bottom of each page
   - `:summary` - Report summary, appears once at report end

2. **Band Attributes**:
   - `type` - One of the band types above
   - `group_level` - For group bands, specifies nesting level (1, 2, 3, etc.)
   - `detail_number` - For multiple detail bands (detail band 1, 2, etc.)
   - `target_alias` - Expression for related resource alias
   - `on_entry` / `on_exit` - Ash expressions for band lifecycle hooks
   - `elements` - Report elements (fields, labels, expressions, etc.)
   - `options` - Band-specific configuration

3. **Recursive Band Processing**:
   - Bands can contain sub-bands via `recursive_as: :sub_bands`
   - Processing follows depth-first traversal
   - Context is maintained through the band hierarchy
   - Data binding flows from parent to child bands

### Report Variable System

Variables enable calculations and state management across report execution:

1. **Variable Types**:
   - `:sum` - Running sum of values
   - `:count` - Count of items
   - `:average` - Running average
   - `:min` / `:max` - Minimum/maximum values
   - `:custom` - Custom calculation via Ash expression

2. **Reset Scopes**:
   - `:detail` - Reset for each detail row
   - `:group` - Reset when group changes (specify `reset_group` level)
   - `:page` - Reset on page breaks
   - `:report` - Never reset (report-wide accumulation)

3. **Variable Context**:
   - Variables are evaluated in band context
   - Can reference other variables
   - Support complex Ash expressions
   - Thread-safe for concurrent report generation

### Module Generation Strategy

The transformers generate specific modules at compile-time:

1. **Base Report Module**: `Domain.Reports.ReportName`
   - Contains report definition
   - Coordinates format-specific renderers
   - Handles data fetching via Ash queries
   - Manages report lifecycle

2. **Format-Specific Modules**: `Domain.Reports.ReportName.Html`, `.Pdf`, `.Heex`
   - Implement format-specific rendering logic
   - Can share common rendering components
   - Support format-specific options

3. **Query Generation**:
   - Leverages Ash.Query for data fetching
   - Automatic relationship loading based on report structure
   - Aggregate pre-loading for performance
   - Respects Ash policies and authorization

### Rendering Pipeline

1. **Data Flow**:
   ```
   Report Definition → Query Generation → Data Fetching → Band Processing → Element Rendering → Format Output
   ```

2. **Band Processing Order**:
   - Process bands in hierarchical order
   - Maintain context between parent/child bands
   - Handle group breaks and aggregations
   - Manage page breaks for paginated formats

3. **Element Types**:
   - `:field` - Data field from resource
   - `:label` - Static text label
   - `:expression` - Calculated value via Ash expression
   - `:aggregate` - Aggregated value (sum, count, etc.)
   - `:line` - Visual separator
   - `:box` - Container element
   - `:image` - Image element

### Code Generation Best Practices

1. **Use Spark.Dsl.Transformer APIs**:
   - `Transformer.eval/3` for code evaluation
   - `Transformer.add_entity/3` for adding entities
   - `Transformer.persist/3` for cross-transformer data
   - `Transformer.get_persisted/2` for retrieving persisted data

2. **Avoid Compilation Deadlocks**:
   - Never call functions on the module being compiled
   - Work with DSL state, not module functions
   - Use `get_persisted(dsl_state, :module)` carefully

3. **Error Handling**:
   - Always provide clear error messages
   - Include DSL path context in errors
   - Use `Spark.Error.DslError` for consistency

### Technical Implementation Details

1. **Variable State Management**:
   - Create `VariableState` module for thread-safe calculations
   - Support dependency resolution between variables
   - Implement reset scopes: `:detail`, `:group`, `:page`, `:report`
   - Track variable values throughout report execution

2. **Group Processing Engine**:
   - Build `GroupProcessor` for multi-level group break detection
   - Track group values for proper header/footer rendering
   - Support arbitrary nesting levels
   - Handle group sorting and value changes

3. **Streaming Architecture**:
   - Default chunk size: 1000 records
   - Memory usage must stay under 1.5x baseline
   - Use `Stream.resource/3` for lazy evaluation
   - Support backpressure for slow consumers

4. **Caching Strategy**:
   - ETS-based cache with configurable TTL (default: 5 minutes)
   - Cache key generation from report name + params hash
   - Track cache hits in report metadata
   - Support manual cache invalidation

5. **MCP Server Protocol**:
   - Implement TCP server with JSON-RPC 2.0
   - Required methods: `initialize`, `tools/list`, `tools/call`
   - Tool naming: `report_<report_name>`
   - Include authentication mechanism
   - Handle connection errors gracefully

6. **Telemetry Events**:
   - Emit at: `[:ash, :report, :run, :start]` and `[:ash, :report, :run, :stop]`
   - Measurements: `duration`, `record_count`, `memory_used`
   - Metadata: `report`, `format`, `cache_hit`, `actor`
   - Support custom event handlers

### Elixir Guard Clauses and Compile-Time Constraints

**IMPORTANT**: When writing validation functions or pattern matching with `in` operator:

1. **Guard clauses require compile-time values** - You cannot use function calls like `band_types()` or `format_types()` in guard clauses
2. **Use regular conditionals instead** - Replace guard clauses with `if/else` statements when checking against dynamic lists:
   ```elixir
   # WRONG - This will cause compilation errors
   defp validate_type(%{type: type}) when type in band_types(), do: :ok
   
   # CORRECT - Use regular conditional
   defp validate_type(%{type: type}) do
     if type in band_types() do
       :ok
     else
       {:error, "Invalid band type"}
     end
   end
   ```

3. **For struct field defaults** - Use `Keyword.merge/2` correctly to ensure options override defaults:
   ```elixir
   # Merge defaults first, then apply user options
   def new(name, opts \\ []) do
     struct(
       __MODULE__,
       default_values()
       |> Keyword.merge(opts)
       |> Keyword.put(:name, name)
     )
   end
   ```

### Working Spark Extension

When looking at how code should be written you can inspire yourself by the [AshCommanded](https://github.com/accountex-org/ash_commanded) project.

### Extension Integration Points

1. **Domain Extension (`AshReports.Domain`)**:
   - Extends `Ash.Domain` with a `reports` section
   - Generates report modules under `Domain.Reports.*`
   - Manages domain-wide report configuration
   - Coordinates report registration and access

2. **Resource Extension (`AshReports.Resource`)**:
   - Extends `Ash.Resource` with a `reportable` section
   - Defines which fields/calculations are exposed to reports
   - Can include resource-specific report definitions
   - Adds report-related actions to resources

3. **Integration with Ash Features**:
   - **Policies**: Reports respect Ash authorization policies
   - **Calculations**: Can use Ash calculations in report elements
   - **Aggregates**: Leverages Ash aggregates for summaries
   - **Relationships**: Automatically loads required relationships
   - **Filters**: Applies Ash filters to report data

### Report Parameters and Runtime Configuration

1. **Parameter Definition**:
   ```elixir
   parameters do
     parameter :start_date, :date, required: true
     parameter :end_date, :date, required: true
     parameter :region, :string
   end
   ```

2. **Parameter Usage**:
   - In scope definitions via Ash expressions
   - In band filters and conditions
   - In element conditional display
   - In variable calculations

3. **Runtime Options**:
   - Format selection (HTML, PDF, HEEX)
   - Locale for internationalization
   - Page size and orientation (for PDF)
   - Custom styling options

### Performance Optimization Strategies

1. **Query Optimization**:
   - Pre-load all required relationships in one query
   - Use database-level aggregations when possible
   - Implement query result caching
   - Support streaming for large datasets

2. **Compile-Time Optimization**:
   - Generate efficient code at compile time
   - Pre-calculate static elements
   - Optimize band traversal paths
   - Minimize runtime reflection

3. **Memory Management**:
   - Stream large reports instead of loading all data
   - Clear intermediate results after band processing
   - Use ETS for report state during generation
   - Implement pagination for web display

### Testing Strategy Requirements

1. **Unit Tests**:
   - Test each DSL entity (Report, Band, Column)
   - Test transformers and verifiers independently
   - Test query generation logic
   - Test format-specific renderers
   - Use standardized test helpers (`build_test_report/0`, `create_test_data/0`)
   - Create consistent test domains (e.g., `TestDomain`, `TestResource`)

2. **Integration Tests**:
   - Test complete report generation flow
   - Test with real Ash domains and resources
   - Test authorization and policy enforcement
   - Test multi-format output generation
   - **Phased Integration Testing**: Each phase needs dedicated integration tests (e.g., `test/integration/phase1_test.exs`)
   - Use `eventually/2` helper for async operations with timeout

3. **Performance Tests**:
   - Test with large datasets (10k+ records)
   - Test concurrent report generation (handle 50+ concurrent reports)
   - Test memory usage patterns (should stay under 1.5x baseline with streaming)
   - Test query optimization effectiveness
   - Use `@tag :performance` for performance tests
   - Monitor memory with `:erlang.memory(:total)`
   - **Performance Benchmarks**:
     - Simple reports (< 100 records): < 100ms
     - Medium reports (1,000 records): < 1 second
     - Large reports (10,000 records): < 10 seconds
     - Cached responses: 10x faster than initial generation

4. **Test Coverage Goals**:
   - DSL parsing and validation: 100%
   - Core logic (bands, variables, groups): 95%
   - Renderers: 90%  
   - Server components: 85%
   - Integration points: 80%

5. **Test Automation**:
   - Unit tests on every commit
   - Integration tests on PR
   - Performance tests nightly
   - System tests before release

### Security Considerations

1. **Authorization**:
   - Reports require explicit permissions
   - Data access follows Ash policies
   - Runtime parameter validation
   - Audit trail for report execution

2. **Data Protection**:
   - Sanitize user inputs in parameters
   - Prevent SQL injection via Ash queries
   - Secure file paths for output
   - Encrypt sensitive report data

### CLDR Integration for Internationalization

1. **Format Types**:
   - `:date` / `:datetime` - Locale-aware date formatting
   - `:currency` - Currency formatting with symbols
   - `:number` - Number formatting with separators
   - `:percentage` - Percentage formatting
   - `:unit` - Unit formatting (weight, length, etc.)

2. **Locale Support**:
   - Reports accept locale parameter
   - All text elements support translation
   - Format specifications are locale-aware
   - Right-to-left language support

### Common Implementation Pitfalls to Avoid

1. **DSL Design**:
   - Don't mix validation in transformers
   - Avoid circular dependencies between bands
   - Don't assume entity order in transformers
   - Keep entity schemas focused and simple

2. **Code Generation**:
   - Avoid runtime module compilation
   - Don't generate invalid Elixir code
   - Handle all error cases in transformers
   - Test generated code thoroughly

3. **Performance**:
   - Don't load unnecessary data
   - Avoid N+1 query problems
   - Don't hold large datasets in memory
   - Cache expensive calculations

### Report Definition Flow
1. DSL definition in domain/resource → 2. Transformer processing → 3. Generated report modules → 4. Runtime rendering

The system generates dedicated modules for each report format at compile time, providing type-safe report generation.

### DSL Structure from System Design

Based on the comprehensive system design, the DSL should implement:

1. **Report Entity Schema**:
   - `name` (atom, required) - Report identifier
   - `title` (string) - Display title
   - `description` (string) - Report description
   - `driving_resource` (atom) - Main Ash resource
   - `scope` (any) - Ash.Query for data scope
   - `bands` (list of Band entities) - Report structure
   - `variables` (list of Variable entities) - Calculations
   - `groups` (list of Group entities) - Grouping definitions
   - `permissions` (list of atoms) - Required permissions
   - `parameters` (list of Parameter entities) - Runtime params

2. **Band Entity Schema**:
   - `type` (one of the 11 band types)
   - `group_level` (integer) - For group bands
   - `detail_number` (integer) - For multiple detail bands
   - `target_alias` (any) - Resource alias expression
   - `on_entry` / `on_exit` (any) - Lifecycle expressions
   - `elements` (list of Element entities)
   - `options` (keyword_list) - Band-specific config

3. **Element Entity Schema**:
   - `type` (field/label/expression/aggregate/line/box/image)
   - `source` (any) - Field path or expression
   - `format` (any) - CLDR format specification
   - `position` (keyword_list) - Layout coordinates
   - `style` (keyword_list) - Visual styling
   - `conditional` (any) - Display condition expression

4. **Variable Entity Schema**:
   - `name` (atom, required) - Variable identifier
   - `type` (sum/count/average/min/max/custom)
   - `expression` (any) - Calculation expression
   - `reset_on` (detail/group/page/report)
   - `reset_group` (integer) - For group resets
   - `initial_value` (any) - Starting value

### Key Files to Understand

- `planning/system_design.md` - Comprehensive architecture documentation with implementation details
- `planning/implementation_plan.md` - Detailed implementation plan in phases.
- `planning/report_design.md` - Hierarchical band structure specification defining the 9-level report band system (title, page header, column header, group header, detail, group footer, column footer, page footer, summary) that must be implemented in the DSL and rendering engine
- `lib/ash_reports.ex` - Main module (currently placeholder)
- `mix.exs` - Project configuration and dependencies
- `config/config.exs` - Ash and Spark configuration

When extending this codebase, follow the established patterns for Spark DSL extensions and maintain integration with Ash Framework conventions.

### Implementation 
The development of the extension should follow the `planning/implementation_plan.md` development plan and proceed
phase by phase and section by section. 

**CRITICAL TESTING REQUIREMENT**: 
- NO step in the implementation plan may be marked as completed `[x]` unless it has comprehensive tests written and they all pass.
- Each new module, function, or feature MUST have corresponding test coverage
- Tests should cover both happy path and error cases
- Integration tests should be written for complex interactions between modules
- Performance tests should be included for data-intensive operations

Each step needs to be properly tested and have all its tests passing before moving to the next step of the plan.

### Implementation Phases Overview

**Phase 1: Core Foundation and DSL Framework** (weeks 1-4)
1. Create `Ash.Report` extension module and core DSL schema
2. Implement Band hierarchy with validation transformer
3. Build Element system with position and style schemas
4. Create basic Registry for report storage

**Phase 2: Data Integration and Query System** (weeks 5-8)
1. Build QueryBuilder for scope and parameter handling
2. Implement Variable system with state management and reset logic
3. Create GroupProcessor for multi-level break detection
4. Develop DataLoader with streaming support

**Phase 3: Rendering Engine and Output Formats** (weeks 9-13)
1. Create Renderer behavior and context management
2. Implement renderers in order: HTML → HEEX → PDF → JSON
3. Add layout calculation and element builders
4. Test cross-format consistency

**Phase 4: Internationalization and Formatting** (weeks 14-16)
1. Integrate ex_cldr with locale support
2. Create format specification DSL
3. Update renderers for locale awareness
4. Add RTL support and translations

**Phase 5: Server Infrastructure** (weeks 17-20)
1. Build GenServer for report management
2. Implement ETS-based caching with TTL
3. Create MCP server with protocol support
4. Add monitoring and telemetry

**Phase 6: Advanced Features and Polish** (weeks 21-24)
1. Create Ash.Resource.Reportable extension
2. Optimize performance and streaming
3. Enhance security with row-level controls
4. Complete monitoring and observability

## GitHub Project Management

The project uses a comprehensive script-based system for managing GitHub issues, milestones, and project boards:

### Script Management System
- **Interactive Manager**: `./github/scripts/project_manager.sh` - Central interface for all project management operations
- **Execution Logging**: All script runs are tracked in `github/scripts/execution_log.md` with timestamps and outcomes
- **Documentation**: `github/scripts/README.md` contains complete usage workflows and best practices

### Key Scripts
- `update_project_status.sh` - Updates project board when phases complete (mark issues as Done, close completed tasks)
- `create_github_milestones.sh` - Creates phase-based milestones from implementation plan
- `create_github_issues_batch.sh` - Generates issues from implementation tasks
- `update_issues_backlog.sh` - Manages issue status transitions and backlog organization

### Workflow Integration
When making progress on implementation phases:
1. Update `planning/implementation_plan.md` to mark completed tasks with `[x]`
2. Commit the plan changes to git using standard commit message format WITHOUT any co-authorship attribution
3. Run `./github/scripts/project_manager.sh` or `./github/scripts/update_project_status.sh` to update GitHub project board
4. Script automatically marks completed issues as Done and closes them with completion comments

**IMPORTANT**: Git commit messages should be professional and focused on the technical changes. Do NOT include any co-authorship attribution, AI tool references, or generation acknowledgments.

### Best Practices
- Always commit implementation plan changes before running status update scripts
- Use the interactive project manager for complex operations
- All script executions are logged for audit trails
- Project state backups are available through the management system

This ensures GitHub project boards stay synchronized with actual development progress as documented in the implementation plan.


