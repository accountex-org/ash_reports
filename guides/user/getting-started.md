# Getting Started with AshReports

AshReports is a comprehensive reporting extension for the Ash Framework that provides declarative report definitions with hierarchical band structures, multiple output formats, and internationalization support.

> **Note**: This guide reflects the current implementation. For planned features, see [ROADMAP.md](../../ROADMAP.md).

## Table of Contents

- [Installation](#installation)
- [Basic Concepts](#basic-concepts)
- [Your First Report](#your-first-report)
- [Understanding Band Types](#understanding-band-types)
- [Element Types](#element-types)
- [Output Formats](#output-formats)
- [Next Steps](#next-steps)

## Installation

Add `ash_reports` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_reports, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to install the dependency.

## Basic Concepts

AshReports is built around several core concepts:

### Reports
A **report** is the top-level container that defines:
- Data source (driving resource)
- Structure (bands and elements)
- Parameters for dynamic filtering
- Variables for calculations
- Output format specifications

### Bands
**Bands** are horizontal sections of a report that organize content hierarchically:
- **Title**: Report title and headers
- **Page Header/Footer**: Content that appears on every page
- **Group Header/Footer**: Content for data groupings
- **Detail**: The main data rows
- **Column Header/Footer**: Column labels and summaries
- **Summary**: Overall report summaries

### Elements
**Elements** are the individual components within bands:
- **Fields**: Data from your Ash resources
- **Labels**: Static text
- **Expressions**: Calculated values
- **Aggregates**: Sum, count, average, etc.
- **Visual**: Lines, boxes, images
- **Charts**: Basic chart visualizations

### Variables
**Variables** accumulate values across report execution:
- Sum totals, counts, averages, min/max
- Reset at different scopes (detail, group, page, report)
- Used in expressions and conditional logic

## Your First Report

Let's create a simple customer report to demonstrate the basic structure.

### 1. Add AshReports to Your Domain

```elixir
defmodule MyApp.MyDomain do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  resources do
    resource MyApp.Customer
    resource MyApp.Invoice
  end

  reports do
    # Reports will be defined here
  end
end
```

### 2. Create a Basic Customer List Report

```elixir
defmodule MyApp.MyDomain do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  resources do
    resource MyApp.Customer
  end

  reports do
    report :customer_list do
      title("Customer Directory")
      description("A simple list of all customers")
      driving_resource(MyApp.Customer)

      band :title do
        type :title

        label :report_title do
          text("Customer Directory")
          style font_size: 18, font_weight: :bold, text_align: :center
        end
      end

      band :column_header do
        type :column_header
        columns "(1fr, 1fr, 100pt)"

        label :name_header do
          text("Customer Name")
          column 0
          style font_weight: :bold
        end

        label :email_header do
          text("Email")
          column 1
          style font_weight: :bold
        end

        label :status_header do
          text("Status")
          column 2
          style font_weight: :bold
        end
      end

      band :details do
        type :detail
        columns "(1fr, 1fr, 100pt)"

        field :customer_name do
          source :name
          column 0
        end

        field :customer_email do
          source :email
          column 1
        end

        field :customer_status do
          source :status
          column 2
        end
      end
    end
  end
end
```

### 3. Generate the Report

```elixir
# Generate HTML output
{:ok, result} = AshReports.generate(
  MyApp.MyDomain,
  :customer_list,
  %{},
  :html
)

html_content = result.content

# Generate PDF output
{:ok, result} = AshReports.generate(
  MyApp.MyDomain,
  :customer_list,
  %{},
  :pdf
)

pdf_content = result.content

# Generate JSON export
{:ok, result} = AshReports.generate(
  MyApp.MyDomain,
  :customer_list,
  %{},
  :json
)

json_content = result.content
```

## Understanding Band Types

AshReports supports 11 different band types, each serving a specific purpose:

### Layout Bands
- **`:title`** - Report title, appears once at the beginning
- **`:page_header`** - Appears at the top of each page
- **`:page_footer`** - Appears at the bottom of each page
- **`:summary`** - Report summary, appears once at the end

### Data Bands
- **`:column_header`** - Column labels for data
- **`:column_footer`** - Column totals and summaries
- **`:detail`** - Main data rows (can have multiple detail bands)
- **`:detail_header`** - Headers for detail sections
- **`:detail_footer`** - Footers for detail sections

### Grouping Bands
- **`:group_header`** - Headers when data groups change
- **`:group_footer`** - Footers with group subtotals

### Band Type Usage Example

```elixir
band :page_header do
  type :page_header

  label :page_title do
    text("My Company - Customer Report")
  end
end

band :group_header do
  type :group_header
  group_level(1)  # First level grouping
  columns "(auto, 1fr)"

  label :group_title do
    text("Region: ")
    column 0
    style font_weight: :bold
  end

  field :region_name do
    source :region
    column 1
    style font_weight: :bold
  end
end
```

## Element Types

### Field Elements
Display data from your Ash resource attributes:

```elixir
band :details do
  type :detail
  columns "(1fr, 100pt, 100pt)"

  field :customer_name do
    source :name
    format :text
    column 0
  end

  field :invoice_total do
    source :total
    format :currency
    column 1
    style text_align: :right
  end

  field :created_date do
    source :inserted_at
    format :date
    column 2
  end
end
```

### Label Elements
Static text content:

```elixir
label :section_title do
  text("Customer Information")
  style font_size: 14, font_weight: :bold, color: "#333333"
end
```

### Expression Elements
Calculated values using Ash expressions:

```elixir
expression :full_name do
  expression(:first_name)  # Will be enhanced with actual expression support
  column 0
end
```

> **Note**: Full Ash expression support in expressions is a work in progress. See [ROADMAP.md Phase 4](../../ROADMAP.md#phase-4-performance-and-optimization).

### Aggregate Elements
Statistical calculations within bands:

```elixir
band :summary do
  type :summary
  columns "(1fr, 100pt)"

  aggregate :total_customers do
    function(:count)
    source :id
    scope :report
    column 1
    style text_align: :right
  end

  aggregate :average_order_value do
    function(:average)
    source :total
    scope :group
    format :currency
    column 1
    style text_align: :right
  end
end
```

#### Charts

Charts are defined at the reports level and referenced in bands:

```elixir
# At reports level - define chart
bar_chart :sales_chart do
  data_source expr(monthly_sales_data())

  config do
    width 800
    height 400
    title "Sales by Month"
    type :simple
    colours ["4285F4", "34A853"]
  end
end

# In band - reference chart
band :analytics do
  type :detail

  elements do
    bar_chart :sales_chart
  end
end
```

> **Supported Chart Types**: Bar, Line, Pie, Area, Scatter, Gantt, and Sparkline charts via Contex. See [Graphs and Visualizations](graphs-and-visualizations.md) for complete documentation.

## Output Formats

AshReports supports multiple output formats:

### HTML
Web-friendly output with CSS styling:
```elixir
{:ok, result} = AshReports.Runner.run_report(
  domain,
  :report_name,
  params,
  format: :html
)
```

### PDF
Print-ready documents:
```elixir
{:ok, result} = AshReports.Runner.run_report(
  domain,
  :report_name,
  params,
  format: :pdf
)
```

### HEEX
LiveView templates for interactive reports:
```elixir
{:ok, result} = AshReports.Runner.run_report(
  domain,
  :report_name,
  params,
  format: :heex
)
```

### JSON
Structured data for API consumption:
```elixir
{:ok, result} = AshReports.Runner.run_report(
  domain,
  :report_name,
  params,
  format: :json
)
```

> **Note**: Renderer implementations are currently in testing phase. See [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current status.

## Next Steps

Now that you understand the basics, explore these topics:

1. **[Report Creation Guide](report-creation.md)** - Learn to build reports with parameters, grouping, and variables
2. **[Graphs and Visualizations](graphs-and-visualizations.md)** - Add charts to your reports
3. **[Advanced Features](advanced-features.md)** - Formatting and internationalization
4. **[Integration Guide](integration.md)** - Integrate AshReports with Phoenix and LiveView

## Common Patterns

### Simple List Report
Use for basic data listings with minimal formatting - exactly like the example above.

### Master-Detail Report
Use detail bands with relationship loading to show hierarchical data.

### Financial Report
Use variables and aggregates for running totals and calculations.

### Grouped Report
Use group_header and group_footer bands with group definitions.

## Troubleshooting

### Common Issues

1. **Missing band elements**: Ensure all bands have at least one element or are conditionally hidden
2. **Positioning conflicts**: Check that element positions don't overlap unintentionally
3. **Format errors**: Verify format specifications match data types
4. **Resource permissions**: Ensure proper read permissions on driving resources

### Debug Mode
Monitor report generation:
```elixir
{:ok, result} = AshReports.Runner.run_report(
  domain,
  :report_name,
  params,
  format: :html,
  include_debug_data: true
)

# Result includes timing and metadata
IO.inspect(result.metadata)
```

## Implementation Status

AshReports is under active development. Core DSL and band system are production-ready, but some features are still being tested:

- ✅ Core DSL infrastructure
- ✅ Band hierarchy system
- ✅ Basic element types
- ✅ Parameter and variable definitions
- ⚠️ Renderer implementations (needs testing)
- ⚠️ Full data loading pipeline (in progress)
- 🔵 Advanced chart engine (planned)

See [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for complete details and [ROADMAP.md](../../ROADMAP.md) for planned features.
