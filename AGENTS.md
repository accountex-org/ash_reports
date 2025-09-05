# AshReports Codebase Guidelines for Agentic Coding Agents

## Build/Lint/Test Commands
- **Build**: `mix compile`
- **Run all tests**: `mix test`
- **Run a specific test file**: `mix test test/<file_path>`
- **Run test at line number**: `mix test test/<file_path>:<line_number>`
- **Lint code (with Credo)**: `mix credo --strict`
- **Dialyzer for type checking**: `mix dialyzer`

## Code Style Guidelines
### Imports & Formatting
- Use `@import_deps` in `.formatter.exs`: `[Spark.Formatter]`
- Follow Spark formatter conventions (configured in `.formatter.exs`)
- Use proper Elixir module structure with `defmodule/2` and `do/end` blocks

### Naming Conventions
- **Modules**: Snake_case for directories, CamelCase for modules (`AshReports.Dsl.Report`)
- **Functions**: snake_case with descriptive names (`calculate_total_price/2`)
- **Variables**: snake_case with meaningful names (`total_amount`, `user_data`)
- **Atoms**: snake_case for boolean flags and states (`:active`, `:pending`)

### Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Prefer pattern matching over try/catch blocks where possible
- Log errors appropriately with `Logger.error/4`

### Types & Specs
- Define module attributes (`@moduledoc`, `@doc`) for documentation
- Use function specifications (`@spec`) to define expected types
- Follow OTP principles and best practices

### Testing
- Write tests in files ending with `_test.exs` in the `test/` directory
- Use ExUnit for testing: assertions, setup/teardown, mocking with Mox
- Structure tests with descriptive test names and clear assertions

## Ash Framework Specific Guidelines
- Follow Ash DSL syntax rules (disabled specific Credo checks for compatibility)
- Use proper resource patterns and domain-driven design principles
- Be aware of the disabled Credo checks: `LargeNumbers` and `ParenthesesInCondition`