# Report Creation Guide

This guide covers report creation techniques in AshReports, including parameters, grouping, variables, and formatting.

> **Note**: This guide reflects the current implementation. For planned features like advanced conditional formatting and streaming configuration, see [ROADMAP.md](../../ROADMAP.md).

## Table of Contents

- [Report Structure](#report-structure)
- [Parameters and Filtering](#parameters-and-filtering)
- [Variables and Calculations](#variables-and-calculations)
- [Grouping and Sorting](#grouping-and-sorting)
- [Format Specifications](#format-specifications)
- [Complete Examples](#complete-examples)

## Report Structure

### Basic Report Definition

Every AshReports report follows this fundamental structure:

```elixir
report :report_name do
  # Metadata
  title("Report Display Title")
  description("What this report shows")
  driving_resource(MyApp.SomeResource)

  # Optional: Supported output formats
  formats([:html, :pdf, :json, :heex])

  # Optional: Required permissions
  permissions([:view_reports, :view_customers])

  # Report components
  parameter :start_date, :date do
    required(true)
  end

  format_spec :company_currency do
    pattern "¤ #,##0.00"
    currency :USD
  end

  variable :running_total do
    type :sum
    expression :total_amount
    reset_on :report
  end

  group :by_region do
    level 1
    expression :region
    sort :asc
  end

  band :title do
    type :title
    # elements...
  end
end
```

### Resource Relationships

Access related data through Ash relationships:

```elixir
report :invoice_report do
  driving_resource(MyApp.Invoice)

  band :details do
    type :detail

    # Direct attribute
    field :invoice_number do
      source :invoice_number
    end

    # Related data via belongs_to
    field :customer_name do
      source :customer.name
    end

    # Nested relationships (if preloaded)
    field :customer_region do
      source :customer.address.region
    end
  end
end
```

> **Note**: Relationship loading and preloading is handled by the data loader. Ensure your driving resource has the appropriate relationships defined.

## Parameters and Filtering

Parameters make reports dynamic by allowing runtime filtering and customization.

### Parameter Types

```elixir
# String parameters
parameter :customer_name, :string do
  required(false)
  default ""
end

# Date parameters
parameter :start_date, :date do
  required(true)
end

parameter :end_date, :date do
  required(true)
end

# Atom/enum parameters
parameter :status, :atom do
  required(false)
  constraints one_of: [:draft, :sent, :paid, :overdue]
  default :sent
end

# Numeric parameters
parameter :min_amount, :decimal do
  required(false)
  default Decimal.new("0.00")
end

# Boolean parameters
parameter :include_cancelled, :boolean do
  required(false)
  default false
end

# List parameters
parameter :regions, {:array, :string} do
  required(false)
  default []
end
```

### Using Parameters in Scope

> **Note**: Advanced parameter-based filtering with Ash expressions in `scope` is currently under development. For now, filtering should be handled in the data loading layer.

```elixir
report :filtered_invoices do
  driving_resource(MyApp.Invoice)

  parameter :start_date, :date do
    required(true)
  end

  parameter :end_date, :date do
    required(true)
  end

  parameter :min_amount, :decimal do
    default Decimal.new("0.00")
  end

  # Basic scope (expression support in progress)
  # scope expr(date >= ^start_date and date <= ^end_date)

  band :details do
    type :detail

    field :date do
      source :date
      format :date
    end

    field :total do
      source :total
      format :currency
    end
  end
end
```

### Parameter Constraints

```elixir
# Parameter with validation constraints
parameter :year, :integer do
  required(true)
  constraints min: 2020, max: 2030
  default Date.utc_today().year
end

# String parameter with length constraint
parameter :department_filter, :string do
  required(false)
  constraints max_length: 50
end
```

## Variables and Calculations

Variables accumulate values during report processing and enable running totals, counts, and other calculations.

### Variable Types and Reset Scopes

```elixir
variable :running_total do
  type :sum
  expression :total
  reset_on :report  # Never resets during report
end

variable :invoice_count do
  type :count
  expression :id
  reset_on :page  # Reset on each new page
end

variable :average_amount do
  type :average
  expression :total
  reset_on :group  # Reset when group changes
  reset_group 1    # Reset on first-level group
end

variable :highest_amount do
  type :max
  expression :total
  reset_on :report
end

variable :lowest_amount do
  type :min
  expression :total
  reset_on :report
end

# Custom variable (for complex logic - support in progress)
variable :overdue_total do
  type :custom
  expression :total  # Will be enhanced with conditional logic
  reset_on :group
  initial_value Decimal.new("0.00")
end
```

### Using Variables in Elements

```elixir
band :group_footer do
  type :group_footer
  group_level(1)

  label :group_total_label do
    text("Group Total:")
    position(x: 60, y: 0, width: 20, height: 12)
  end

  # Display variable value
  expression :group_total_value do
    expression :running_total  # References the variable
    format :currency
    position(x: 80, y: 0, width: 20, height: 12)
  end
end

band :summary do
  type :summary

  label :summary_title do
    text("Report Summary")
    style(font_weight: :bold, font_size: 16)
  end

  expression :total_invoices do
    expression :invoice_count  # References the count variable
  end

  expression :grand_total do
    expression :running_total  # References the sum variable
    format :currency
  end
end
```

## Grouping and Sorting

Grouping organizes data into hierarchical sections with headers and footers.

### Single-Level Grouping

```elixir
group :by_customer do
  level 1
  expression :customer_name
  sort :asc
end

band :group_header_customer do
  type :group_header
  group_level(1)

  label :customer_label do
    text("Customer: ")
    style(font_weight: :bold)
  end

  field :customer_name do
    source :customer.name
    style(font_weight: :bold, font_size: 14)
  end
end

band :details do
  type :detail

  field :invoice_number do
    source :invoice_number
  end

  field :date do
    source :date
    format :date
  end

  field :total do
    source :total
    format :currency
  end
end

band :group_footer_customer do
  type :group_footer
  group_level(1)

  aggregate :customer_total do
    function :sum
    source :total
    scope :group
    format :currency
  end

  aggregate :customer_count do
    function :count
    source :id
    scope :group
  end
end
```

### Multi-Level Grouping

```elixir
group :by_region do
  level 1
  expression :region
  sort :asc
end

group :by_customer do
  level 2
  expression :customer_name
  sort :asc
end

# Level 1 group header (Region)
band :region_header do
  type :group_header
  group_level(1)

  label :region_title do
    text("Region: ")
    style(font_weight: :bold, font_size: 16)
  end

  field :region_name do
    source :customer.region
    style(font_weight: :bold, font_size: 16)
  end
end

# Level 2 group header (Customer within Region)
band :customer_header do
  type :group_header
  group_level(2)

  label :customer_title do
    text("  Customer: ")
    style(font_weight: :bold)
  end

  field :customer_name do
    source :customer.name
    style(font_weight: :bold)
  end
end

# Detail band
band :details do
  type :detail

  field :invoice_number do
    source :invoice_number
    position(x: 20, y: 0, width: 20, height: 12)  # Indented
  end

  field :total do
    source :total
    format :currency
    position(x: 80, y: 0, width: 20, height: 12)
  end
end

# Level 2 group footer (Customer subtotals)
band :customer_footer do
  type :group_footer
  group_level(2)

  label :customer_subtotal_label do
    text("  Customer Subtotal:")
    position(x: 40, y: 0, width: 40, height: 12)
  end

  aggregate :customer_subtotal do
    function :sum
    source :total
    scope :group
    format :currency
    position(x: 80, y: 0, width: 20, height: 12)
  end
end

# Level 1 group footer (Region totals)
band :region_footer do
  type :group_footer
  group_level(1)

  label :region_total_label do
    text("Region Total:")
    style(font_weight: :bold)
    position(x: 40, y: 0, width: 40, height: 12)
  end

  aggregate :region_total do
    function :sum
    source :total
    scope :group
    format :currency
    style(font_weight: :bold)
    position(x: 80, y: 0, width: 20, height: 12)
  end
end
```

## Format Specifications

Format specifications provide reusable formatting rules that can be applied consistently across elements.

### Basic Format Specifications

```elixir
format_spec :company_currency do
  pattern "¤ #,##0.00"
  currency :USD
  locale "en"
end

format_spec :short_date do
  pattern "MM/dd/yy"
  type :date
end

format_spec :percentage do
  pattern "#0.0%"
  type :percentage
end

format_spec :uppercase_text do
  transform :uppercase
  max_length 50
  truncate_suffix "..."
end
```

### Conditional Format Specifications (Basic)

> **Note**: Advanced conditional formatting with expressions is planned. See [ROADMAP.md Phase 7](../../ROADMAP.md#phase-7-advanced-formatting). Current implementation supports basic keyword list conditions.

```elixir
format_spec :amount_formatting do
  pattern "#,##0.00"
  type :currency
  currency :USD

  # Basic conditions (keyword list format)
  conditions [
    high_value: [pattern: "#,##0K", color: :green],
    negative_value: [pattern: "(#,##0.00)", color: :red]
  ]

  fallback "#,##0.00"
end
```

### Using Format Specifications

```elixir
band :details do
  type :detail

  field :amount do
    source :total
    format_spec :company_currency  # Reference the format spec
  end

  field :created_date do
    source :inserted_at
    format_spec :short_date
  end

  field :description do
    source :description
    format_spec :uppercase_text
  end
end
```

### Simple Inline Formatting

```elixir
band :details do
  type :detail

  # Simple format type
  field :invoice_total do
    source :total
    format :currency
  end

  # Date formatting
  field :invoice_date do
    source :date
    format :date
  end

  # Number formatting
  field :quantity do
    source :quantity
    format :number
  end

  # Text (default)
  field :customer_name do
    source :customer.name
    format :text
  end
end
```

## Complete Examples

### Sales Report with Grouping and Variables

```elixir
report :sales_by_region_report do
  title("Sales Analysis by Region")
  description("Detailed sales report with regional grouping")
  driving_resource(MyApp.Invoice)

  parameter :start_date, :date do
    required(true)
  end

  parameter :end_date, :date do
    required(true)
  end

  parameter :min_amount, :decimal do
    default Decimal.new("0.00")
  end

  format_spec :sales_currency do
    pattern "$#,##0.00"
    currency :USD
  end

  variable :running_total do
    type :sum
    expression :total
    reset_on :report
  end

  variable :region_total do
    type :sum
    expression :total
    reset_on :group
    reset_group 1
  end

  variable :invoice_count do
    type :count
    expression :id
    reset_on :group
    reset_group 1
  end

  group :by_region do
    level 1
    expression :region
    sort :asc
  end

  # Report title
  band :title do
    type :title

    label :main_title do
      text("Sales Analysis by Region")
      style(font_size: 20, font_weight: :bold)
      position(x: 0, y: 0, width: 100, height: 20)
    end
  end

  # Page header
  band :page_header do
    type :page_header

    label :company_name do
      text("ACME Corporation")
      style(font_weight: :bold)
      position(x: 0, y: 0, width: 50, height: 15)
    end
  end

  # Region group header
  band :region_header do
    type :group_header
    group_level(1)

    label :region_label do
      text("Region: ")
      style(font_weight: :bold, font_size: 16)
      position(x: 0, y: 0, width: 15, height: 15)
    end

    field :region_name do
      source :customer.region
      style(font_weight: :bold, font_size: 16)
      position(x: 15, y: 0, width: 50, height: 15)
    end

    line :region_separator do
      orientation :horizontal
      thickness 2
      position(x: 0, y: 16, width: 100, height: 2)
    end
  end

  # Column headers
  band :column_header do
    type :column_header

    label :date_header do
      text("Date")
      style(font_weight: :bold)
      position(x: 0, y: 0, width: 20, height: 12)
    end

    label :customer_header do
      text("Customer")
      style(font_weight: :bold)
      position(x: 20, y: 0, width: 40, height: 12)
    end

    label :invoice_header do
      text("Invoice #")
      style(font_weight: :bold)
      position(x: 60, y: 0, width: 20, height: 12)
    end

    label :amount_header do
      text("Amount")
      style(font_weight: :bold)
      position(x: 80, y: 0, width: 20, height: 12)
    end
  end

  # Detail rows
  band :details do
    type :detail

    field :invoice_date do
      source :date
      format :date
      position(x: 0, y: 0, width: 20, height: 12)
    end

    field :customer_name do
      source :customer.name
      position(x: 20, y: 0, width: 40, height: 12)
    end

    field :invoice_number do
      source :invoice_number
      position(x: 60, y: 0, width: 20, height: 12)
    end

    field :invoice_amount do
      source :total
      format_spec :sales_currency
      position(x: 80, y: 0, width: 20, height: 12)
    end
  end

  # Region footer
  band :region_footer do
    type :group_footer
    group_level(1)

    label :region_summary_title do
      text("Region Summary")
      style(font_weight: :bold, font_size: 14)
      position(x: 0, y: 0, width: 60, height: 12)
    end

    label :region_total_label do
      text("Region Total:")
      style(font_weight: :bold, font_size: 14)
      position(x: 60, y: 0, width: 20, height: 12)
    end

    expression :region_total_value do
      expression :region_total
      format_spec :sales_currency
      style(font_weight: :bold, font_size: 14)
      position(x: 80, y: 0, width: 20, height: 12)
    end
  end

  # Report summary
  band :summary do
    type :summary

    label :summary_title do
      text("Report Summary")
      style(font_size: 18, font_weight: :bold)
      position(x: 0, y: 0, width: 100, height: 20)
    end

    expression :grand_total_display do
      expression :running_total
      format_spec :sales_currency
      style(font_size: 16, font_weight: :bold)
      position(x: 0, y: 25, width: 100, height: 15)
    end
  end
end
```

### Usage Example

```elixir
# Generate the report with parameters
params = %{
  start_date: ~D[2024-01-01],
  end_date: ~D[2024-12-31],
  min_amount: Decimal.new("500.00")
}

{:ok, result} = AshReports.generate(
  MyApp.MyDomain,
  :sales_by_region_report,
  params,
  :html
)

html_report = result.content

# Generate PDF version
{:ok, result} = AshReports.generate(
  MyApp.MyDomain,
  :sales_by_region_report,
  params,
  :pdf
)

pdf_report = result.content
```

### Financial Summary Report

```elixir
report :financial_summary do
  title("Monthly Financial Summary")
  driving_resource(MyApp.Transaction)

  parameter :month, :integer do
    required(true)
    constraints min: 1, max: 12
  end

  parameter :year, :integer do
    required(true)
  end

  format_spec :accounting_currency do
    pattern "$#,##0.00"
    currency :USD
    type :currency
  end

  variable :revenue_total do
    type :sum
    expression :revenue
    reset_on :report
  end

  variable :expense_total do
    type :sum
    expression :expenses
    reset_on :report
  end

  band :title do
    type :title

    label :report_title do
      text("Monthly Financial Summary")
      style(font_size: 24, font_weight: :bold)
    end
  end

  band :details do
    type :detail

    field :date do
      source :transaction_date
      format :date
    end

    field :description do
      source :description
    end

    field :revenue do
      source :revenue
      format_spec :accounting_currency
    end

    field :expenses do
      source :expenses
      format_spec :accounting_currency
    end
  end

  band :summary do
    type :summary

    label :revenue_label do
      text("Total Revenue:")
      style(font_weight: :bold)
    end

    expression :revenue_amount do
      expression :revenue_total
      format_spec :accounting_currency
      style(font_weight: :bold)
    end

    label :expense_label do
      text("Total Expenses:")
      style(font_weight: :bold)
    end

    expression :expense_amount do
      expression :expense_total
      format_spec :accounting_currency
      style(font_weight: :bold)
    end
  end
end
```

## Best Practices

### Report Organization

1. **Use clear naming**: Name reports, bands, and elements descriptively
2. **Group logically**: Organize bands in a logical flow (title → headers → details → footers → summary)
3. **Consistent positioning**: Use a grid system for element positioning
4. **Reusable format specs**: Define format specifications once, use everywhere

### Performance Considerations

1. **Limit preloading**: Only preload relationships you actually use
2. **Use aggregates wisely**: Database aggregates are more efficient than variables for simple sums
3. **Consider data volume**: For large datasets, ensure proper indexing on group and sort fields

> **Note**: Advanced streaming configuration and performance monitoring features are planned. See [ROADMAP.md Phase 4](../../ROADMAP.md#phase-4-performance-and-optimization).

### Maintainability

1. **Document parameters**: Use clear descriptions for all parameters
2. **Test with real data**: Always test reports with realistic data volumes
3. **Version your reports**: Consider report definitions as code and version control them

## Limitations and Planned Features

### Current Limitations

- **Expression support**: Full Ash expression syntax in calculations is under development
- **Conditional formatting**: Expression-based conditions are planned (basic keyword list conditions work)
- **Scope expressions**: Parameter interpolation in scope expressions is in progress
- **Streaming configuration**: Report-level streaming DSL is planned

### See Also

- [ROADMAP.md](../../ROADMAP.md) - Planned features and timeline
- [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) - Current implementation status
- [Advanced Features Guide](advanced-features.md) - What's currently available in advanced features
- [Graphs and Visualizations](graphs-and-visualizations.md) - Chart integration

## Next Steps

1. Explore [graphs and visualizations](graphs-and-visualizations.md) to add charts to your reports
2. Learn about [integration](integration.md) with Phoenix and LiveView
3. Check out [advanced features](advanced-features.md) for formatting and internationalization basics
