# Getting Started with AshReports

AshReports is a comprehensive reporting extension for the Ash Framework that provides declarative report definitions with hierarchical band structures, multiple output formats, and internationalization support.

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

### Variables
**Variables** accumulate values across report execution:
- Sum totals, counts, averages
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
      title "Customer Directory"
      description "A simple list of all customers"
      driving_resource MyApp.Customer

      bands do
        band :title do
          type :title
          elements do
            label :report_title do
              text "Customer Directory"
              position x: 0, y: 0, width: 100, height: 20
              style font_size: 18, font_weight: :bold, alignment: :center
            end
          end
        end

        band :column_header do
          type :column_header
          elements do
            label :name_header do
              text "Customer Name"
              position x: 0, y: 0, width: 40, height: 15
              style font_weight: :bold
            end
            
            label :email_header do
              text "Email"
              position x: 40, y: 0, width: 40, height: 15
              style font_weight: :bold
            end
            
            label :status_header do
              text "Status"
              position x: 80, y: 0, width: 20, height: 15
              style font_weight: :bold
            end
          end
        end

        band :details do
          type :detail
          elements do
            field :customer_name do
              source :name
              position x: 0, y: 0, width: 40, height: 12
            end
            
            field :customer_email do
              source :email
              position x: 40, y: 0, width: 40, height: 12
            end
            
            field :customer_status do
              source :status
              position x: 80, y: 0, width: 20, height: 12
            end
          end
        end
      end
    end
  end
end
```

### 3. Generate the Report

```elixir
# Generate HTML output
{:ok, html_content} = AshReports.generate(MyApp.MyDomain, :customer_list, %{}, :html)

# Generate PDF output
{:ok, pdf_content} = AshReports.generate(MyApp.MyDomain, :customer_list, %{}, :pdf)
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
  elements do
    label :page_title do
      text "My Company - Customer Report"
      position x: 0, y: 0, width: 80, height: 15
    end
    
    expression :page_number do
      expression expr("Page " <> page_number)
      position x: 80, y: 0, width: 20, height: 15
      style alignment: :right
    end
  end
end

band :group_header do
  type :group_header
  group_level 1  # First level grouping
  elements do
    label :group_title do
      text "Region: "
      position x: 0, y: 0, width: 15, height: 15
      style font_weight: :bold
    end
    
    field :region_name do
      source :region
      position x: 15, y: 0, width: 25, height: 15
      style font_weight: :bold
    end
  end
end
```

## Element Types

### Field Elements
Display data from your Ash resource attributes:

```elixir
field :customer_name do
  source :name
  format :text
  position x: 0, y: 0, width: 40, height: 12
end

field :invoice_total do
  source :total
  format :currency
  position x: 40, y: 0, width: 20, height: 12
end

field :created_date do
  source :inserted_at
  format :date
  custom_pattern "MM/dd/yyyy"
  position x: 60, y: 0, width: 20, height: 12
end
```

### Label Elements
Static text content:

```elixir
label :section_title do
  text "Customer Information"
  position x: 0, y: 0, width: 100, height: 15
  style font_size: 14, font_weight: :bold, color: "#333333"
end
```

### Expression Elements
Calculated values using Ash expressions:

```elixir
expression :full_name do
  expression expr(first_name <> " " <> last_name)
  position x: 0, y: 0, width: 40, height: 12
end

expression :days_since_created do
  expression expr(date_diff(^Date.utc_today(), inserted_at, :day))
  format :number
  position x: 40, y: 0, width: 20, height: 12
end
```

### Aggregate Elements
Statistical calculations:

```elixir
aggregate :total_customers do
  function :count
  source :id
  scope :report
  position x: 0, y: 0, width: 20, height: 12
end

aggregate :average_order_value do
  function :average
  source :total
  scope :group
  format :currency
  position x: 20, y: 0, width: 20, height: 12
end
```

### Visual Elements

#### Lines
```elixir
line :separator do
  orientation :horizontal
  thickness 2
  position x: 0, y: 15, width: 100, height: 2
  style color: "#cccccc"
end
```

#### Boxes
```elixir
box :section_box do
  position x: 0, y: 0, width: 100, height: 50
  border width: 1, color: "#000000", style: :solid
  fill color: "#f5f5f5"
end
```

#### Images
```elixir
image :company_logo do
  source "/images/logo.png"
  scale_mode :fit
  position x: 0, y: 0, width: 20, height: 15
end
```

## Output Formats

AshReports supports multiple output formats:

### HTML
Web-friendly output with CSS styling:
```elixir
{:ok, html} = AshReports.generate(domain, :report_name, params, :html)
```

### PDF
Print-ready documents:
```elixir
{:ok, pdf} = AshReports.generate(domain, :report_name, params, :pdf)
```

### HEEX
LiveView templates for interactive reports:
```elixir
{:ok, heex} = AshReports.generate(domain, :report_name, params, :heex)
```

### JSON
Structured data for API consumption:
```elixir
{:ok, json} = AshReports.generate(domain, :report_name, params, :json)
```

## Next Steps

Now that you understand the basics, explore these advanced topics:

1. **[Report Creation Guide](report-creation.md)** - Learn to build complex reports with parameters, grouping, and variables
2. **[Graphs and Visualizations](graphs-and-visualizations.md)** - Add charts and interactive visualizations
3. **[Advanced Features](advanced-features.md)** - Formatting, internationalization, and performance optimization
4. **[Integration Guide](integration.md)** - Integrate AshReports with Phoenix, LiveView, and external systems

## Common Patterns

### Simple List Report
Use for basic data listings with minimal formatting.

### Master-Detail Report
Use grouping bands to show hierarchical data relationships.

### Financial Report
Use variables and aggregates for running totals and calculations.

### Dashboard Report
Combine multiple chart elements for visual data presentation.

## Troubleshooting

### Common Issues

1. **Missing band elements**: Ensure all bands have at least one element
2. **Positioning conflicts**: Check that element positions don't overlap
3. **Format errors**: Verify format specifications match data types
4. **Resource permissions**: Ensure proper read permissions on driving resources

### Debug Mode
Enable detailed logging:
```elixir
config :ash_reports, debug: true
```

This will help identify issues with report generation and data loading.