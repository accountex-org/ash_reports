
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
3. **Transformers** - Code generation at compile time
4. **Verifiers ** - DSL validation at compile time
5. **Recursive Entities** - Bands can contain sub-bands with arbitrary nesting

### Working Spark Extension

When looking at how code should be written you can inspire yourself by the [AshCommanded](https://github.com/accountex-org/ash_commanded) project.

### Report Definition Flow
1. DSL definition in domain/resource → 2. Transformer processing → 3. Generated report modules → 4. Runtime rendering

The system generates dedicated modules for each report format at compile time, providing type-safe report generation.

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


