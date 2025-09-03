# AshReports Demo

A comprehensive demonstration of the AshReports library featuring a complete business invoicing system with customers, products, and invoices.

## Quick Start

```bash
# Install dependencies
mix deps.get

# Start interactive session
iex -S mix

# Generate sample data
AshReportsDemo.generate_sample_data(:medium)

# Get data summary
AshReportsDemo.data_summary()

# List available reports (more added in later phases)
AshReportsDemo.list_reports()
```

## Project Structure

This demo showcases:

- **Phase 7.1**: Project structure and dependencies ✅
- **Phase 7.2**: Domain model and business resources (upcoming)
- **Phase 7.3**: Data generation with Faker (upcoming)
- **Phase 7.4**: Advanced Ash features (upcoming)
- **Phase 7.5**: Comprehensive report definitions (upcoming)
- **Phase 7.6**: Integration and documentation (upcoming)

## Current Status

Phase 7.1 provides:
- Complete Phoenix project structure
- Ash domain configuration
- ETS data layer for zero-configuration operation
- Data generation framework
- Basic testing infrastructure

## Development

```bash
# Run tests
mix test

# Check code quality
mix credo

# Generate documentation
mix docs
```

## Features (Coming in Later Phases)

- Realistic business data with Faker integration
- 8 interconnected business resources
- 4 comprehensive reports showcasing all AshReports features
- Multi-format output (HTML, HEEX, PDF, JSON)
- Interactive demos and performance benchmarks