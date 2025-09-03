# Report Creation Guide

This guide covers advanced report creation techniques in AshReports, including parameters, grouping, variables, conditional formatting, and complex data relationships.

## Table of Contents

- [Report Structure](#report-structure)
- [Parameters and Filtering](#parameters-and-filtering)
- [Variables and Calculations](#variables-and-calculations)
- [Grouping and Sorting](#grouping-and-sorting)
- [Format Specifications](#format-specifications)
- [Conditional Formatting](#conditional-formatting)
- [Master-Detail Reports](#master-detail-reports)
- [Complete Examples](#complete-examples)

## Report Structure

### Basic Report Definition

Every AshReports report follows this fundamental structure:

```elixir
report :report_name do
  # Metadata
  title "Report Display Title"
  description "What this report shows"
  driving_resource MyApp.SomeResource
  
  # Optional: Scope the data
  scope expr(status == :active)
  
  # Optional: Required permissions
  permissions [:view_reports, :view_customers]
  
  # Optional: Supported output formats
  formats [:html, :pdf, :json]

  # Report components
  parameters do
    # Dynamic filtering
  end
  
  format_specs do
    # Reusable formatting
  end
  
  variables do
    # Running calculations
  end
  
  groups do
    # Data grouping
  end
  
  bands do
    # Report layout and content
  end
end
```

### Resource Relationships

Access related data through Ash relationships:

```elixir
report :invoice_report do
  driving_resource MyApp.Invoice
  
  bands do
    band :details do
      type :detail
      elements do
        # Direct attribute
        field :invoice_number do
          source :invoice_number
        end
        
        # Related data via belongs_to
        field :customer_name do
          source :customer.name
        end
        
        # Related data via has_many with aggregation
        field :line_item_count do
          source :line_item_count  # This is an aggregate
        end
        
        # Deeply nested relationships
        field :customer_region do
          source :customer.address.region
        end
      end
    end
  end
end
```

## Parameters and Filtering

Parameters make reports dynamic by allowing runtime filtering and customization.

### Parameter Types

```elixir
parameters do
  # String parameters
  parameter :customer_name, :string do
    description "Filter by customer name (partial match)"
    default ""
  end
  
  # Date parameters
  parameter :start_date, :date, required: true do
    description "Report start date"
  end
  
  parameter :end_date, :date, required: true do
    description "Report end date"
  end
  
  # Enum parameters
  parameter :status, :atom do
    description "Filter by status"
    constraints one_of: [:draft, :sent, :paid, :overdue]
    default :sent
  end
  
  # Numeric parameters
  parameter :min_amount, :decimal do
    description "Minimum invoice amount"
    constraints decimal: [min: Decimal.new("0.00")]
    default Decimal.new("0.00")
  end
  
  # Boolean parameters
  parameter :include_cancelled, :boolean do
    description "Include cancelled invoices"
    default false
  end
  
  # List parameters
  parameter :regions, {:array, :string} do
    description "Filter by regions"
    default []
  end
end
```

### Using Parameters in Filters

Parameters are automatically available in expressions via `^parameter_name`:

```elixir
report :filtered_invoices do
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :start_date, :date, required: true
    parameter :end_date, :date, required: true
    parameter :min_amount, :decimal, default: Decimal.new("0.00")
    parameter :customer_id, :uuid
  end
  
  # Apply parameter-based scope
  scope expr(
    date >= ^start_date and 
    date <= ^end_date and 
    total >= ^min_amount and
    if(not is_nil(^customer_id), customer_id == ^customer_id, true)
  )
  
  bands do
    band :details do
      type :detail
      elements do
        field :date do
          source :date
          format :date
        end
        
        field :total do
          source :total
          format :currency
        end
        
        # Use parameters in conditional display
        field :customer_name do
          source :customer.name
          conditional expr(is_nil(^customer_id))  # Only show when not filtering by customer
        end
      end
    end
  end
end
```

### Advanced Parameter Usage

```elixir
parameters do
  # Parameter with validation
  parameter :year, :integer do
    constraints min: 2020, max: 2030
    default Date.utc_today().year
  end
  
  # Parameter with dynamic default
  parameter :current_month, :integer do
    default Date.utc_today().month
  end
  
  # Optional parameter with conditional logic
  parameter :department_filter, :string do
    description "Optional department filter"
  end
end

# Use parameters in complex expressions
scope expr(
  date_part(date, :year) == ^year and
  if(not is_nil(^department_filter), 
     customer.department == ^department_filter, 
     true)
)
```

## Variables and Calculations

Variables accumulate values during report processing and enable running totals, counts, and other calculations.

### Variable Types and Reset Scopes

```elixir
variables do
  # Sum variable - accumulates totals
  variable :running_total do
    type :sum
    expression expr(total)
    reset_on :report  # Reset at report level (never resets)
  end
  
  # Count variable
  variable :invoice_count do
    type :count
    expression expr(id)
    reset_on :page  # Reset on each new page
  end
  
  # Average variable
  variable :average_amount do
    type :average
    expression expr(total)
    reset_on :group  # Reset when group changes
    reset_group 1    # Reset on first-level group
  end
  
  # Min/Max variables
  variable :highest_amount do
    type :max
    expression expr(total)
    reset_on :report
  end
  
  variable :lowest_amount do
    type :min
    expression expr(total)
    reset_on :report
  end
  
  # Custom variable with complex logic
  variable :overdue_total do
    type :custom
    expression expr(
      if(status == :overdue, total, Decimal.new("0.00"))
    )
    reset_on :group
    initial_value Decimal.new("0.00")
  end
end
```

### Using Variables in Elements

```elixir
bands do
  band :group_footer do
    type :group_footer
    group_level 1
    elements do
      label :group_total_label do
        text "Group Total:"
        position x: 60, y: 0, width: 20, height: 12
      end
      
      # Display variable value
      expression :group_total_value do
        expression variable(:running_total)
        format :currency
        position x: 80, y: 0, width: 20, height: 12
      end
      
      # Variable in calculation
      expression :average_display do
        expression expr("Avg: " <> to_string(variable(:average_amount)))
        position x: 0, y: 12, width: 40, height: 12
      end
    end
  end
  
  band :summary do
    type :summary
    elements do
      label :summary_title do
        text "Report Summary"
        style font_weight: :bold, font_size: 16
      end
      
      expression :total_invoices do
        expression expr("Total Invoices: " <> to_string(variable(:invoice_count)))
      end
      
      expression :grand_total do
        expression expr("Grand Total: $" <> to_string(variable(:running_total)))
      end
    end
  end
end
```

## Grouping and Sorting

Grouping organizes data into hierarchical sections with headers and footers.

### Single-Level Grouping

```elixir
groups do
  group :by_customer do
    level 1
    expression expr(customer.name)
    sort :asc
  end
end

bands do
  band :group_header_customer do
    type :group_header
    group_level 1
    elements do
      label :customer_label do
        text "Customer: "
        style font_weight: :bold
      end
      
      field :customer_name do
        source :customer.name
        style font_weight: :bold, font_size: 14
      end
    end
  end
  
  band :details do
    type :detail
    elements do
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
  end
  
  band :group_footer_customer do
    type :group_footer
    group_level 1
    elements do
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
  end
end
```

### Multi-Level Grouping

```elixir
groups do
  group :by_region do
    level 1
    expression expr(customer.region)
    sort :asc
  end
  
  group :by_customer do
    level 2
    expression expr(customer.name)
    sort :asc
  end
end

bands do
  # Level 1 group header (Region)
  band :region_header do
    type :group_header
    group_level 1
    elements do
      label :region_title do
        text "Region: "
        style font_weight: :bold, font_size: 16
      end
      
      field :region_name do
        source :customer.region
        style font_weight: :bold, font_size: 16
      end
    end
  end
  
  # Level 2 group header (Customer within Region)
  band :customer_header do
    type :group_header
    group_level 2
    elements do
      label :customer_title do
        text "  Customer: "
        style font_weight: :bold
      end
      
      field :customer_name do
        source :customer.name
        style font_weight: :bold
      end
    end
  end
  
  # Detail band
  band :details do
    type :detail
    elements do
      field :invoice_number do
        source :invoice_number
        position x: 20, y: 0, width: 20, height: 12  # Indented
      end
      field :total do
        source :total
        format :currency
        position x: 80, y: 0, width: 20, height: 12
      end
    end
  end
  
  # Level 2 group footer (Customer subtotals)
  band :customer_footer do
    type :group_footer
    group_level 2
    elements do
      label :customer_subtotal_label do
        text "  Customer Subtotal:"
        position x: 40, y: 0, width: 40, height: 12
      end
      
      aggregate :customer_subtotal do
        function :sum
        source :total
        scope :group
        format :currency
        position x: 80, y: 0, width: 20, height: 12
      end
    end
  end
  
  # Level 1 group footer (Region totals)
  band :region_footer do
    type :group_footer
    group_level 1
    elements do
      label :region_total_label do
        text "Region Total:"
        style font_weight: :bold
        position x: 40, y: 0, width: 40, height: 12
      end
      
      aggregate :region_total do
        function :sum
        source :total
        scope :group
        format :currency
        style font_weight: :bold
        position x: 80, y: 0, width: 20, height: 12
      end
    end
  end
end
```

## Format Specifications

Format specifications provide reusable formatting rules that can be applied consistently across elements.

### Basic Format Specifications

```elixir
format_specs do
  # Currency formatting
  format_spec :company_currency do
    pattern "¤ #,##0.00"
    currency :USD
    locale "en"
  end
  
  # Date formatting
  format_spec :short_date do
    pattern "MM/dd/yy"
    type :date
  end
  
  # Number formatting
  format_spec :percentage do
    pattern "#0.0%"
    type :percentage
  end
  
  # Text formatting
  format_spec :uppercase_text do
    transform :uppercase
    max_length 50
    truncate_suffix "..."
  end
end
```

### Conditional Format Specifications

```elixir
format_specs do
  format_spec :amount_with_alerts do
    # Default formatting
    pattern "#,##0.00"
    
    # Conditional formatting based on value
    conditions [
      {expr(value > 10000), [pattern: "#,##0K", color: :green, font_weight: :bold]},
      {expr(value < 0), [pattern: "(#,##0.00)", color: :red]},
      {expr(value == 0), [pattern: "-", color: :gray]}
    ]
    
    fallback "#,##0.00"
  end
  
  format_spec :status_formatting do
    conditions [
      {expr(value == :paid), [color: :green, text: "✓ Paid"]},
      {expr(value == :overdue), [color: :red, text: "⚠ Overdue"]},
      {expr(value == :sent), [color: :blue, text: "→ Sent"]},
      {expr(value == :draft), [color: :gray, text: "✎ Draft"]}
    ]
  end
end
```

### Using Format Specifications

```elixir
bands do
  band :details do
    type :detail
    elements do
      field :amount do
        source :total
        format_spec :amount_with_alerts  # Reference the format spec
      end
      
      field :status do
        source :status
        format_spec :status_formatting
      end
      
      field :created_date do
        source :inserted_at
        format_spec :short_date
      end
    end
  end
end
```

## Conditional Formatting

Apply formatting rules based on data values or expressions.

### Element-Level Conditional Formatting

```elixir
bands do
  band :details do
    type :detail
    elements do
      field :invoice_total do
        source :total
        format :currency
        
        # Conditional formatting at element level
        conditional_format [
          {expr(total > 5000), [color: :green, font_weight: :bold]},
          {expr(total < 100), [color: :red, font_style: :italic]},
          {expr(status == :overdue), [background_color: :yellow]}
        ]
      end
      
      field :status_icon do
        source :status
        conditional_format [
          {expr(status == :paid), [text: "✓", color: :green]},
          {expr(status == :overdue), [text: "⚠", color: :red]},
          {expr(status == :sent), [text: "→", color: :blue]}
        ]
      end
      
      # Conditional visibility
      field :overdue_notice do
        source expr("OVERDUE!")
        conditional expr(status == :overdue)  # Only show when overdue
        style color: :red, font_weight: :bold
      end
    end
  end
end
```

### Band-Level Conditional Logic

```elixir
bands do
  # Band only appears for certain conditions
  band :overdue_warning do
    type :detail_header
    visible expr(count(invoices, status == :overdue) > 0)  # Only show if overdue invoices exist
    
    elements do
      label :warning_message do
        text "⚠ This report contains overdue invoices"
        style color: :red, font_weight: :bold, background_color: :yellow
      end
    end
  end
  
  band :vip_customer_header do
    type :group_header
    group_level 1
    visible expr(customer.type == :vip)  # Only for VIP customers
    
    elements do
      label :vip_badge do
        text "⭐ VIP CUSTOMER"
        style color: :gold, font_weight: :bold
      end
    end
  end
end
```

## Master-Detail Reports

Create reports showing hierarchical data relationships with proper grouping and subtotals.

### Invoice with Line Items Example

```elixir
report :invoice_with_line_items do
  title "Invoice Detail Report"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :invoice_id, :uuid, required: true
  end
  
  scope expr(id == ^invoice_id)
  
  variables do
    variable :line_item_total do
      type :sum
      expression expr(line_items.line_total)
      reset_on :report
    end
    
    variable :line_count do
      type :count
      expression expr(line_items.id)
      reset_on :report
    end
  end
  
  bands do
    # Invoice header
    band :invoice_header do
      type :title
      elements do
        label :invoice_title do
          text "INVOICE"
          style font_size: 24, font_weight: :bold
        end
        
        field :invoice_number do
          source :invoice_number
          style font_size: 18
        end
        
        field :invoice_date do
          source :date
          format :date
        end
      end
    end
    
    # Customer information
    band :customer_info do
      type :page_header
      elements do
        label :bill_to_label do
          text "Bill To:"
          style font_weight: :bold
        end
        
        field :customer_name do
          source :customer.name
          style font_size: 14
        end
        
        field :customer_address do
          source :customer.address
        end
      end
    end
    
    # Line items header
    band :line_items_header do
      type :column_header
      elements do
        label :item_header do
          text "Item"
          style font_weight: :bold
        end
        
        label :qty_header do
          text "Qty"
          style font_weight: :bold
        end
        
        label :price_header do
          text "Price"
          style font_weight: :bold
        end
        
        label :total_header do
          text "Total"
          style font_weight: :bold
        end
      end
    end
    
    # Line items detail - using target_alias for related data
    band :line_items_detail do
      type :detail
      target_alias :line_items  # This tells the band to iterate over line_items
      
      elements do
        field :item_description do
          source :product.name  # From the line item's product
        end
        
        field :quantity do
          source :quantity
          format :number
        end
        
        field :unit_price do
          source :unit_price
          format :currency
        end
        
        field :line_total do
          source :line_total
          format :currency
        end
      end
    end
    
    # Invoice totals
    band :invoice_totals do
      type :summary
      elements do
        label :subtotal_label do
          text "Subtotal:"
        end
        
        expression :subtotal_amount do
          expression variable(:line_item_total)
          format :currency
        end
        
        field :tax_amount do
          source :tax_amount
          format :currency
        end
        
        label :total_label do
          text "Total:"
          style font_weight: :bold
        end
        
        field :invoice_total do
          source :total
          format :currency
          style font_weight: :bold
        end
      end
    end
  end
end
```

## Complete Examples

### Comprehensive Sales Report

```elixir
report :comprehensive_sales_report do
  title "Comprehensive Sales Analysis"
  description "Detailed sales report with grouping, variables, and conditional formatting"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :start_date, :date, required: true
    parameter :end_date, :date, required: true
    parameter :region_filter, :string
    parameter :min_amount, :decimal, default: Decimal.new("0.00")
  end
  
  scope expr(
    date >= ^start_date and 
    date <= ^end_date and
    total >= ^min_amount and
    status != :cancelled and
    if(not is_nil(^region_filter), customer.region == ^region_filter, true)
  )
  
  format_specs do
    format_spec :sales_currency do
      pattern "$#,##0.00"
      currency :USD
      conditions [
        {expr(value > 10000), [color: :green, font_weight: :bold]},
        {expr(value < 0), [color: :red, pattern: "($#,##0.00)"]}
      ]
    end
    
    format_spec :performance_indicator do
      conditions [
        {expr(value > 5000), [text: "🔥 Hot", color: :green]},
        {expr(value > 1000), [text: "📈 Good", color: :blue]},
        {expr(value > 0), [text: "📊 OK", color: :gray]},
        {expr(value <= 0), [text: "❌ Poor", color: :red]}
      ]
    end
  end
  
  variables do
    variable :running_total do
      type :sum
      expression expr(total)
      reset_on :report
    end
    
    variable :region_total do
      type :sum
      expression expr(total)
      reset_on :group
      reset_group 1
    end
    
    variable :invoice_count do
      type :count
      expression expr(id)
      reset_on :group
      reset_group 1
    end
    
    variable :avg_invoice_amount do
      type :average
      expression expr(total)
      reset_on :group
      reset_group 1
    end
  end
  
  groups do
    group :by_region do
      level 1
      expression expr(customer.region)
      sort :asc
    end
    
    group :by_month do
      level 2
      expression expr(date_part(date, :month))
      sort :asc
    end
  end
  
  bands do
    # Report title
    band :title do
      type :title
      elements do
        label :main_title do
          text "Comprehensive Sales Analysis"
          style font_size: 20, font_weight: :bold, alignment: :center
        end
        
        expression :date_range do
          expression expr(
            "From " <> to_string(^start_date) <> " to " <> to_string(^end_date)
          )
          style font_size: 12, alignment: :center
        end
      end
    end
    
    # Page header
    band :page_header do
      type :page_header
      elements do
        label :company_name do
          text "ACME Corporation"
          style font_weight: :bold
        end
        
        expression :page_info do
          expression expr("Page " <> to_string(page_number))
          style alignment: :right
        end
        
        expression :generated_on do
          expression expr("Generated: " <> to_string(^DateTime.utc_now()))
          style font_size: 10
        end
      end
    end
    
    # Region group header
    band :region_header do
      type :group_header
      group_level 1
      elements do
        label :region_label do
          text "Region: "
          style font_weight: :bold, font_size: 16
        end
        
        field :region_name do
          source :customer.region
          style font_weight: :bold, font_size: 16
        end
        
        line :region_separator do
          orientation :horizontal
          thickness 2
        end
      end
    end
    
    # Month subheader
    band :month_header do
      type :group_header
      group_level 2
      elements do
        expression :month_name do
          expression expr("Month: " <> to_string(date_part(date, :month)))
          style font_weight: :bold
        end
      end
    end
    
    # Column headers
    band :column_header do
      type :column_header
      elements do
        label :date_header do
          text "Date"
          style font_weight: :bold
        end
        
        label :customer_header do
          text "Customer"
          style font_weight: :bold
        end
        
        label :invoice_header do
          text "Invoice #"
          style font_weight: :bold
        end
        
        label :amount_header do
          text "Amount"
          style font_weight: :bold
        end
        
        label :status_header do
          text "Status"
          style font_weight: :bold
        end
        
        label :performance_header do
          text "Performance"
          style font_weight: :bold
        end
      end
    end
    
    # Detail rows
    band :details do
      type :detail
      elements do
        field :invoice_date do
          source :date
          format :date
        end
        
        field :customer_name do
          source :customer.name
        end
        
        field :invoice_number do
          source :invoice_number
        end
        
        field :invoice_amount do
          source :total
          format_spec :sales_currency
        end
        
        field :status do
          source :status
          conditional_format [
            {expr(status == :paid), [color: :green, text: "✓ Paid"]},
            {expr(status == :overdue), [color: :red, text: "⚠ Overdue"]},
            {expr(status == :sent), [color: :blue, text: "→ Sent"]}
          ]
        end
        
        field :performance do
          source :total
          format_spec :performance_indicator
        end
      end
    end
    
    # Month footer
    band :month_footer do
      type :group_footer
      group_level 2
      elements do
        label :month_total_label do
          text "Month Subtotal:"
          style font_weight: :bold
        end
        
        aggregate :month_total do
          function :sum
          source :total
          scope :group
          format_spec :sales_currency
          style font_weight: :bold
        end
      end
    end
    
    # Region footer
    band :region_footer do
      type :group_footer
      group_level 1
      elements do
        label :region_summary_title do
          text "Region Summary"
          style font_weight: :bold, font_size: 14
        end
        
        expression :region_stats do
          expression expr(
            "Total Invoices: " <> to_string(variable(:invoice_count)) <>
            " | Average: $" <> to_string(variable(:avg_invoice_amount))
          )
        end
        
        label :region_total_label do
          text "Region Total:"
          style font_weight: :bold, font_size: 14
        end
        
        expression :region_total_value do
          expression variable(:region_total)
          format_spec :sales_currency
          style font_weight: :bold, font_size: 14
        end
      end
    end
    
    # Report summary
    band :summary do
      type :summary
      elements do
        label :summary_title do
          text "Report Summary"
          style font_size: 18, font_weight: :bold
        end
        
        expression :grand_total_display do
          expression expr("Grand Total: " <> to_string(variable(:running_total)))
          style font_size: 16, font_weight: :bold
        end
        
        expression :report_params do
          expression expr(
            "Parameters - Start: " <> to_string(^start_date) <>
            ", End: " <> to_string(^end_date) <>
            if(not is_nil(^region_filter), ", Region: " <> ^region_filter, "") <>
            ", Min Amount: $" <> to_string(^min_amount)
          )
          style font_size: 10, font_style: :italic
        end
      end
    end
    
    # Page footer
    band :page_footer do
      type :page_footer
      elements do
        expression :page_numbers do
          expression expr("Page " <> to_string(page_number) <> " of " <> to_string(total_pages))
          style alignment: :right
        end
        
        label :confidential do
          text "Confidential - Internal Use Only"
          style font_size: 8, color: :gray
        end
      end
    end
  end
end
```

This comprehensive example demonstrates:
- Complex parameter usage with multiple types
- Multi-level grouping (region and month)
- Variables with different reset scopes
- Conditional formatting at multiple levels
- Format specifications with complex rules
- Complete band hierarchy from title to page footer
- Aggregate calculations with proper scoping
- Expression-based calculations and text formatting

### Usage Examples

```elixir
# Generate the report with parameters
params = %{
  start_date: ~D[2024-01-01],
  end_date: ~D[2024-12-31],
  region_filter: "North",
  min_amount: Decimal.new("500.00")
}

{:ok, html_report} = AshReports.generate(
  MyApp.MyDomain, 
  :comprehensive_sales_report, 
  params, 
  :html
)

{:ok, pdf_report} = AshReports.generate(
  MyApp.MyDomain, 
  :comprehensive_sales_report, 
  params, 
  :pdf
)
```