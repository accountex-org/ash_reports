# AshReports

**A comprehensive, declarative reporting framework for the Ash ecosystem**

AshReports provides a powerful DSL for defining reports with hierarchical band structures, chart generation, streaming data processing, multiple output formats (HTML, PDF, JSON, HEEX), and full internationalization support.

[![Implementation Status](https://img.shields.io/badge/Status-Production--Capable-yellow)](IMPLEMENTATION_STATUS.md)
[![Test Coverage](https://img.shields.io/badge/Coverage-40--50%25-orange)](IMPLEMENTATION_STATUS.md#test-coverage-status)
[![Security](https://img.shields.io/badge/Security-Hardened-green)](SECURITY.md)

---

## Quick Links

- 📊 [Feature Status Matrix](#feature-status) - What's ready for production
- 🚀 [Quick Start](#quick-start) - Get started in 5 minutes
- 📖 [Documentation](#documentation) - Comprehensive guides
- 🔒 [Security](#security) - Security policy and best practices
- 🗺️ [Roadmap](#implementation-roadmap) - What's coming next
- 🤝 [Contributing](#contributing) - How to contribute

---

## What is AshReports?

AshReports is a **declarative reporting framework** built on the Ash Framework that allows you to define complex reports using a DSL, then generate them in multiple formats with full internationalization support.

### Key Features

- 📝 **Declarative DSL** - Define reports using Spark-powered DSL
- 📊 **Band-Based Layout** - Report/page headers/footers, detail, group sections
- 📈 **Chart Generation** - Bar, line, pie, area, scatter charts with Contex
- 🌊 **Streaming Pipeline** - Memory-efficient processing of large datasets
- 🌍 **Internationalization** - CLDR-based formatting for numbers, dates, currencies
- 📄 **Multiple Formats** - HTML, PDF, JSON, HEEX/LiveView output
- ⚡ **LiveView Integration** - Real-time interactive reports
- 🔐 **Security Hardened** - Safe against atom exhaustion attacks

---

## Feature Status

Quick overview of what's production-ready:

| Feature | Status | Notes |
|---------|--------|-------|
| Core DSL | ✅ Production-Ready | 75 passing tests |
| Band System | ✅ Production-Ready | Full hierarchy support |
| Chart Generation | ✅ Production-Ready | SVG output via Contex |
| Streaming | ✅ Production-Ready | Memory-efficient GenStage |
| Data Loading | ✅ Production-Ready | Ash query integration |
| Internationalization | ✅ Production-Ready | CLDR formatting |
| HTML Renderer | ⚠️ Untested | Implemented, needs tests |
| PDF Renderer | ⚠️ Untested | Implemented, needs tests |
| JSON Renderer | ⚠️ Untested | Implemented, needs tests |
| LiveView | ⚠️ Partial | Basic integration working |

**For detailed feature breakdown and roadmap**, see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)

---

## Quick Start

### Installation

Add `ash_reports` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_reports, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### Define Your First Report

```elixir
defmodule MyApp.Reports.SalesReport do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    report :monthly_sales do
      # Define parameters
      parameter :start_date, :date, allow_nil?: false
      parameter :end_date, :date, allow_nil?: false

      # Define the data source
      resource MyApp.Sales.Order

      # Define query
      query fn report, params ->
        Order
        |> Ash.Query.filter(order_date >= ^params.start_date)
        |> Ash.Query.filter(order_date <= ^params.end_date)
      end

      # Define report header
      band :report_header do
        label :title do
          value "Monthly Sales Report"
          style font_size: 24, font_weight: :bold
        end
      end

      # Define detail section
      band :detail do
        field :order_id
        field :customer_name
        field :order_date, format: :date
        field :total_amount, format: :currency
      end

      # Define report footer with totals
      band :report_footer do
        variable :grand_total do
          calculation :sum, field: :total_amount
        end

        field :grand_total do
          label "Grand Total:"
          format :currency
        end
      end
    end
  end
end
```

### Generate the Report

```elixir
# Generate HTML report
{:ok, html} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{
    start_date: ~D[2024-01-01],
    end_date: ~D[2024-01-31]
  },
  :html
)

# Generate PDF report
{:ok, pdf} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{
    start_date: ~D[2024-01-01],
    end_date: ~D[2024-01-31]
  },
  :pdf
)

# Generate JSON export
{:ok, json} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{
    start_date: ~D[2024-01-01],
    end_date: ~D[2024-01-31]
  },
  :json
)
```

---

## Documentation

### User Guides

- **Getting Started** - `guides/user/01_getting_started.md`
- **Report Structure** - `guides/user/02_report_structure.md`
- **Band Types** - `guides/user/03_band_types.md`
- **Elements** - `guides/user/04_elements.md`
- **Charts** - `guides/user/05_charts.md`
- **Parameters** - `guides/user/06_parameters.md`
- **Variables** - `guides/user/07_variables.md`
- **Formatting** - `guides/user/08_formatting.md`
- **Internationalization** - `guides/user/09_internationalization.md`
- **Streaming** - `guides/user/10_streaming.md`

### API Documentation

Generate API docs locally:

```bash
mix docs
open doc/index.html
```

---

## Advanced Features

### Grouped Reports with Aggregations

```elixir
report :sales_by_category do
  resource MyApp.Sales.Order

  # Group by category
  group_by :category_name do
    sort :category_name, :asc

    # Group header
    band :group_header do
      field :category_name
    end

    # Detail records
    band :detail do
      field :order_id
      field :product_name
      field :amount, format: :currency
    end

    # Group footer with subtotal
    band :group_footer do
      variable :category_total do
        calculation :sum, field: :amount
      end

      field :category_total do
        label "Category Total:"
        format :currency
      end
    end
  end
end
```

### Charts in Reports

```elixir
report :sales_chart do
  resource MyApp.Sales.Order

  band :detail do
    chart :sales_by_month do
      type :bar
      title "Monthly Sales"

      data do
        x_axis field: :month_name
        y_axis field: :total_sales
      end

      style do
        width 800
        height 400
      end
    end
  end
end
```

### Streaming Large Datasets

```elixir
# AshReports automatically streams large datasets
# using a GenStage-based pipeline for memory efficiency

{:ok, html} = AshReports.generate(
  MyApp.Reports.HugeReport,
  :all_transactions,  # Could be millions of records
  %{},
  :html
)
# Memory usage stays constant regardless of dataset size
```

---

## Implementation Roadmap

AshReports is currently undergoing a comprehensive improvement process:

### ✅ Stage 1: Critical Blockers (Current - Week 1)

- [x] Fix broken test suite (DSL tests now passing)
- [x] Patch security vulnerabilities (atom exhaustion fixed)
- [ ] Document implementation status (in progress)

### ⏳ Stage 2: Test Infrastructure & Coverage (Weeks 2-3)

- Add renderer test coverage (0% → 70%)
- Add interactive engine tests
- Security hardening (remove process dictionary usage)

### ⏳ Stage 3: Code Quality & Refactoring (Weeks 4-5)

- Reduce code duplication (25% → <10%)
- Standardize patterns across modules

### ⏳ Stage 4-6: Architecture, Docs, Performance (Months 2-3)

- Template engine abstraction
- Comprehensive documentation
- Performance optimization
- Production hardening

**For detailed roadmap**, see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md#implementation-roadmap)

---

## Security

AshReports takes security seriously. We have:

- ✅ Fixed atom table exhaustion vulnerabilities (HIGH severity)
- ✅ Implemented whitelist-based validation for user input
- ✅ Created comprehensive security documentation
- 🔄 Ongoing process dictionary removal (MEDIUM severity)

**To report security vulnerabilities**, see [SECURITY.md](SECURITY.md)

---

## System Requirements

- **Elixir**: 1.14 or later
- **Erlang/OTP**: 25 or later
- **Ash Framework**: 3.0 or later
- **PostgreSQL**: 13+ (if using AshPostgres)
- **Chrome/Chromium**: Required for PDF generation (ChromicPDF dependency)

---

## Troubleshooting

### Common Issues

**Q: Test compilation errors**
- Ensure all dependencies are installed: `mix deps.get`
- Compile dependencies: `mix deps.compile`
- Try cleaning: `mix clean && mix compile`

**Q: PDF generation fails**
- Install Chrome or Chromium
- Ensure ChromicPDF dependency is configured
- Check system resources (memory)

**Q: Atom exhaustion warnings**
- Update to latest version (fixed in v0.1.1+)
- See [SECURITY.md](SECURITY.md) for details

**Q: Charts not rendering**
- Verify chart configuration DSL
- Check data format matches chart type
- Review chart type support (bar, line, pie, area, scatter)

**Q: Memory issues with large reports**
- Use streaming for datasets >10,000 records (automatic)
- Monitor GenStage backpressure
- Adjust chunk sizes in streaming configuration

**For more troubleshooting help**, see user guides or open an issue.

---

## Testing

Run the test suite:

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ash_reports/dsl_test.exs

# Run tests with coverage
mix test --cover

# Run tests excluding slow integration tests
MIX_ENV=test mix test --exclude integration
```

Current test status:
- **DSL & Entity Tests**: ✅ 75/75 passing
- **Chart Tests**: ✅ Passing
- **Renderer Tests**: ❌ 0% coverage (Stage 2 priority)

---

## Performance

Expected performance characteristics:

| Dataset Size | Memory Usage | Generation Time | Notes |
|--------------|--------------|-----------------|-------|
| <1,000 records | <50 MB | <1 second | Direct processing |
| 1K-10K records | <100 MB | 1-5 seconds | Efficient batching |
| 10K-100K records | <200 MB | 5-30 seconds | Streaming pipeline |
| >100K records | <300 MB | 30s-5min | Streaming + chunks |

**Note**: PDF generation adds overhead due to Chrome rendering. JSON is fastest format.

---

## Contributing

We welcome contributions! However, the project is currently undergoing major refactoring:

**Current Status**: Stage 1 of 6-stage improvement plan
**Timeline**: 3-4 months for full completion
**Coordination**: Required to avoid merge conflicts

### How to Contribute Now

1. **Report Issues** - Bug reports are always welcome
2. **Documentation** - Help improve docs and examples
3. **Wait for CONTRIBUTING.md** - Full contributor guide coming in Stage 5

### Contribution Guidelines (Preliminary)

- Follow Elixir style guide
- Add tests for all new features
- Update documentation
- Keep commits focused and atomic
- Write clear commit messages

**Full CONTRIBUTING.md coming in Stage 5** (Month 2)

---

## Community & Support

- **Issues**: [GitHub Issues](https://github.com/accountex-org/ash_reports/issues)
- **Discussions**: [GitHub Discussions](https://github.com/accountex-org/ash_reports/discussions)
- **Ash Community**: [Ash Framework Discord](https://discord.gg/ash-framework)

---

## License

Copyright 2024 Accountex Organization

Licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built with:
- [Ash Framework](https://ash-hq.org/) - Declarative resource framework
- [Spark](https://github.com/ash-project/spark) - DSL creation library
- [Contex](https://github.com/mindok/contex) - Chart generation
- [CLDR](https://github.com/elixir-cldr/cldr) - Internationalization
- [ChromicPDF](https://github.com/bitcrowd/chromic_pdf) - PDF generation
- [GenStage](https://github.com/elixir-lang/gen_stage) - Streaming pipeline

---

## Project Status

**Current**: Stage 1.3 (Implementation Status Documentation)
**Grade**: B+ (Production-capable with gaps)
**Target**: A (Production-ready)
**ETA**: 3-4 months

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for complete details.
