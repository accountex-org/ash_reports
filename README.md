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
- 🌊 **Streaming Data** - Memory-efficient processing via Ash.stream!
- 🌍 **Internationalization** - CLDR-based formatting for numbers, dates, currencies
- 📄 **Multiple Formats** - HTML, PDF (Typst), JSON, HEEX/LiveView output
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
| Streaming | ✅ Production-Ready | Ash.stream! with keyset pagination |
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
      title("Monthly Sales Report")
      description("Sales report with totals")
      driving_resource(MyApp.Sales.Order)

      # Define parameters
      parameter :start_date, :date do
        required(true)
      end

      parameter :end_date, :date do
        required(true)
      end

      # Define variable for totals
      variable :grand_total do
        type :sum
        expression :total_amount
        reset_on :report
      end

      # Define report header
      band :report_header do
        type :title

        label :title do
          text("Monthly Sales Report")
          style(font_size: 24, font_weight: :bold)
        end
      end

      # Define detail section
      band :detail do
        type :detail

        field :order_id do
          source :order_id
        end

        field :customer_name do
          source :customer_name
        end

        field :order_date do
          source :order_date
          format :date
        end

        field :total_amount do
          source :total_amount
          format :currency
        end
      end

      # Define report footer with totals
      band :report_footer do
        type :summary

        label :total_label do
          text("Grand Total:")
          style(font_weight: :bold)
        end

        expression :grand_total_value do
          expression :grand_total
          format :currency
          style(font_weight: :bold)
        end
      end
    end
  end
end
```

### Generate the Report

```elixir
# Generate HTML report
{:ok, result} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]},
  :html
)

html_content = result.content

# Generate PDF report
{:ok, result} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]},
  :pdf
)

pdf_content = result.content

# Generate JSON export
{:ok, result} = AshReports.generate(
  MyApp.Reports.SalesReport,
  :monthly_sales,
  %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]},
  :json
)

json_content = result.content
```

---

## Documentation

### User Guides

- **[Getting Started](guides/user/getting-started.md)** - Installation and first report
- **[Report Creation](guides/user/report-creation.md)** - Parameters, grouping, variables, formatting
- **[Graphs and Visualizations](guides/user/graphs-and-visualizations.md)** - Adding charts to reports
- **[Integration](guides/user/integration.md)** - Phoenix and LiveView integration
- **[Advanced Features](guides/user/advanced-features.md)** - Formatting and current advanced capabilities
- **[ROADMAP.md](ROADMAP.md)** - Planned features and development timeline

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
  title("Sales by Category")
  driving_resource(MyApp.Sales.Order)

  # Define group
  group :by_category do
    level 1
    expression :category_name
    sort :asc
  end

  # Define variable for category totals
  variable :category_total do
    type :sum
    expression :amount
    reset_on :group
    reset_group 1
  end

  # Group header
  band :group_header do
    type :group_header
    group_level(1)

    field :category_name do
      source :category_name
      style(font_weight: :bold)
    end
  end

  # Detail records
  band :detail do
    type :detail

    field :order_id do
      source :order_id
    end

    field :product_name do
      source :product_name
    end

    field :amount do
      source :amount
      format :currency
    end
  end

  # Group footer with subtotal
  band :group_footer do
    type :group_footer
    group_level(1)

    label :total_label do
      text("Category Total:")
      style(font_weight: :bold)
    end

    expression :category_total_value do
      expression :category_total
      format :currency
      style(font_weight: :bold)
    end
  end
end
```

### Band Padding and Spacing

Control the spacing within bands using the `padding` option. This is particularly useful for indenting detail rows in grouped reports or adding vertical spacing to section headers.

```elixir
report :sales_by_region do
  title("Sales by Region")
  driving_resource(MyApp.Sales.Order)

  group :region do
    level 1
    expression :region_name
  end

  # Group header - no padding
  band :group_header do
    type :group_header
    group_level(1)

    field :region_name do
      source :region_name
      style(font_weight: :bold, font_size: 14)
    end
  end

  # Detail records - indented 20pt from left
  band :detail do
    type :detail
    padding left: "20pt"  # Indent detail rows

    field :order_id do
      source :order_id
    end

    field :customer_name do
      source :customer_name
    end

    field :amount do
      source :amount
      format :currency
    end
  end

  # Group footer with subtotal - moderate indent
  band :group_footer do
    type :group_footer
    group_level(1)
    padding left: "10pt", top: "5pt"  # Slight indent and top spacing

    label :total_label do
      text("Region Total:")
      style(font_weight: :bold)
    end

    expression :region_total do
      expression :region_total_var
      format :currency
    end
  end
end
```

**Padding Options:**

- **Directional padding**: `padding left: "20pt", right: "10pt", top: "5pt", bottom: "5pt"`
- **Uniform padding**: `padding "15pt"` (applies to all sides)
- **Unspecified sides default to "5pt"**

**Common use cases:**
- Indent detail rows under group headers
- Add vertical spacing between sections
- Create visual hierarchy in reports

### Charts in Reports

Charts use a two-level architecture: define charts at the reports level, then reference them in bands.

```elixir
defmodule MyApp.Reports do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    # Define reusable chart at reports level
    bar_chart :sales_by_month do
      data_source expr(aggregate_monthly_sales())

      config do
        width 800
        height 400
        title "Monthly Sales"
        type :grouped
        data_labels true
        colours ["4285F4", "34A853", "FBBC04"]
      end
    end

    # Use chart in report
    report :sales_report do
      title "Sales Report"
      driving_resource MyApp.Sales.Order

      bands do
        band :analytics do
          type :detail

          elements do
            # Reference the chart by name
            bar_chart :sales_by_month
          end
        end
      end
    end
  end
end
```

### Streaming Large Datasets

```elixir
# AshReports has streaming infrastructure for large datasets
# using Ash.stream! with keyset pagination for memory efficiency

{:ok, result} = AshReports.generate(
  MyApp.Reports.HugeReport,
  :all_transactions,  # Could be millions of records
  %{},
  :html
)

html_content = result.content

# Note: Streaming configuration DSL is planned.
# See ROADMAP.md Phase 4 for details.
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

---

## Troubleshooting

### Common Issues

**Q: Test compilation errors**
- Ensure all dependencies are installed: `mix deps.get`
- Compile dependencies: `mix deps.compile`
- Try cleaning: `mix clean && mix compile`


**Q: Atom exhaustion warnings**
- Update to latest version (fixed in v0.1.1+)
- See [SECURITY.md](SECURITY.md) for details

**Q: Charts not rendering**
- Verify chart configuration DSL
- Check data format matches chart type
- Review chart type support (bar, line, pie, area, scatter)

**Q: Memory issues with large reports**
- Use streaming for datasets >10,000 records (automatic)
- Adjust batch_size in streaming configuration
- Consider using keyset pagination for optimal performance

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
| 10K-100K records | <200 MB | 5-30 seconds | Streaming |
| >100K records | <300 MB | 30s-5min | Streaming + chunks |

**Note**: PDF generation uses Typst for high-quality output. JSON is fastest format.

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
- [Typst](https://typst.app/) - Document typesetting for PDF generation

---

## Project Status

**Current**: Stage 1.3 (Implementation Status Documentation)
**Grade**: B+ (Production-capable with gaps)
**Target**: A (Production-ready)
**ETA**: 3-4 months

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for complete details.
