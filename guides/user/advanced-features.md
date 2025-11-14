# Advanced Features

This guide covers the currently available advanced features in AshReports, including basic internationalization support and formatting capabilities.

> **Important**: Many advanced features like comprehensive i18n, security DSL, caching, monitoring, and custom extensions are planned but not yet implemented. See [ROADMAP.md](../../ROADMAP.md) for the complete roadmap of planned features.

## Table of Contents

- [Basic Internationalization](#basic-internationalization)
- [Format Specifications](#format-specifications)
- [Conditional Visibility](#conditional-visibility)
- [Band Control Options](#band-control-options)
- [Column-Based Layout](#column-based-layout)
- [Element Styling](#element-styling)
- [Planned Advanced Features](#planned-advanced-features)

## Basic Internationalization

AshReports has CLDR as a dependency and provides basic locale and currency support in format specifications.

### Current i18n Capabilities

```elixir
report :basic_i18n_report do
  title "Sales Report"
  driving_resource MyApp.Invoice

  # Basic format spec with locale and currency
  format_spec :company_currency do
    pattern "¤ #,##0.00"
    currency :USD
    locale "en"
  end

  format_spec :euro_currency do
    pattern "¤ #,##0.00"
    currency :EUR
    locale "de"
  end

  band :details do
    type :detail

    field :amount_usd do
      source :amount
      format_spec :company_currency
    end

    field :amount_eur do
      source :amount_converted
      format_spec :euro_currency
    end
  end
end
```

### Format Specification Options

The format_spec entity supports these internationalization-related options:

```elixir
format_spec :localized_format do
  pattern "¤ #,##0.00"      # Number pattern with currency symbol
  type :currency             # :number, :currency, :percentage, :date, :time, :datetime, :text
  locale "en"                # Locale string (e.g., "en", "es", "de", "fr")
  currency :USD              # Currency atom (e.g., :USD, :EUR, :GBP)

  # Text transformations
  transform :uppercase       # :none, :uppercase, :lowercase, :titlecase
  max_length 50              # Maximum text length
  truncate_suffix "..."      # Suffix when text is truncated

  # Number precision
  precision 2                # Decimal places for numbers
end
```

### Planned i18n Features

> **Note**: Comprehensive i18n features are planned for Phase 3. See [ROADMAP.md Phase 3](../../ROADMAP.md#phase-3-advanced-internationalization).

Planned features include:
- ❌ Per-element locale specification
- ❌ RTL language support and layout mirroring
- ❌ Gettext integration for translatable strings
- ❌ Dynamic locale switching
- ❌ Calendar system selection
- ❌ Multi-currency conversion

Example of planned features (NOT currently available):

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 3

report :multilingual_report do
  locale_variants [:en, :es, :fr, :ar, :he]  # NOT IMPLEMENTED

  parameter :locale, :string do
    default "en"
  end

  band :title do
    type :title

    label :title do
      text gettext("Sales Report")  # NOT IMPLEMENTED
      text_direction :rtl           # NOT IMPLEMENTED
    end

    field :amount do
      source :total
      locale ^locale_param           # NOT IMPLEMENTED
      format_spec :dynamic_currency  # NOT IMPLEMENTED
    end
  end
end
```

## Format Specifications

Format specifications are the primary way to apply consistent formatting across your reports.

### Basic Format Specifications

```elixir
# Currency formatting
format_spec :usd_currency do
  pattern "$#,##0.00"
  currency :USD
  type :currency
end

# Date formatting
format_spec :short_date do
  pattern "MM/dd/yyyy"
  type :date
end

# Number formatting
format_spec :decimal_two_places do
  pattern "#,##0.00"
  type :number
  precision 2
end

# Percentage formatting
format_spec :percentage do
  pattern "#0.0%"
  type :percentage
end

# Text formatting
format_spec :uppercase_limited do
  transform :uppercase
  max_length 30
  truncate_suffix "..."
end
```

### Using Format Specifications

Apply format specs to fields, expressions, and aggregates:

```elixir
band :details do
  type :detail

  field :customer_name do
    source :customer.name
    format_spec :uppercase_limited
  end

  field :order_date do
    source :date
    format_spec :short_date
  end

  field :total do
    source :total
    format_spec :usd_currency
  end
end

band :summary do
  type :summary

  aggregate :grand_total do
    function :sum
    source :total
    scope :report
    format_spec :usd_currency
  end
end
```

### Simple Inline Formatting

For simple cases, use inline format types:

```elixir
field :amount do
  source :total
  format :currency  # Simple currency formatting
end

field :created_at do
  source :inserted_at
  format :date  # Simple date formatting
end

field :quantity do
  source :qty
  format :number  # Simple number formatting
end
```

### Conditional Formatting (Basic)

> **Note**: Advanced conditional formatting with expressions is planned. See [ROADMAP.md Phase 7](../../ROADMAP.md#phase-7-advanced-formatting). Current implementation supports basic keyword list conditions.

```elixir
format_spec :status_formatting do
  pattern "#,##0.00"
  type :currency

  # Basic conditions (keyword list format)
  conditions [
    high_value: [pattern: "#,##0K", color: :green],
    low_value: [pattern: "#,##0", color: :red]
  ]

  fallback "#,##0.00"
end
```

Planned conditional formatting (NOT YET AVAILABLE):

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 7

format_spec :advanced_conditional do
  conditions [
    {expr(value > 10000 and growth > 0.15), [
      pattern: "#,##0K",
      color: :gold,
      background: "#1e3a8a",
      prefix: "🏆 "
    ]},
    {expr(value < 0), [
      pattern: "(#,##0.00)",
      color: :red
    ]}
  ]
  fallback "#,##0.00"
end
```

## Conditional Visibility

Control element visibility with the `conditional` option:

```elixir
band :details do
  type :detail

  # Element with conditional visibility
  field :discount do
    source :discount_amount
    format :currency
    conditional expr(discount_amount > 0)  # Only show if discount exists
  end

  label :premium_badge do
    text "PREMIUM"
    conditional expr(customer_tier == "premium")
  end
end
```

> **Note**: Full expression support is under development. Current conditional logic may be limited.

## Band Control Options

Bands support various control options for layout and behavior:

### Height and Sizing

```elixir
band :header do
  type :page_header

  height 50             # Fixed height in rendering units
  can_grow true         # Allow band to expand for content (default: true)
  can_shrink false      # Allow band to shrink if content is smaller (default: false)
  keep_together true    # Prevent page breaks within band (default: false)
end
```

### Conditional Bands

```elixir
band :premium_section do
  type :detail

  visible expr(customer_tier == "premium")  # Show band conditionally

  # Elements...
end
```

### Group Bands

```elixir
band :region_header do
  type :group_header
  group_level 1  # First level grouping

  # Elements for group header...
end

band :customer_header do
  type :group_header
  group_level 2  # Second level grouping (sub-groups)

  # Elements for sub-group header...
end
```

### Multiple Detail Bands

```elixir
band :detail_products do
  type :detail
  detail_number 1  # First detail band

  # Product fields...
end

band :detail_services do
  type :detail
  detail_number 2  # Second detail band

  # Service fields...
end
```

### Repeating Headers

Control whether page headers and group headers repeat on every page:

```elixir
band :page_header do
  type :page_header
  repeat_on_pages true  # Repeat on all pages (default)

  # Header elements...
end

band :region_header do
  type :group_header
  group_level 1
  repeat_on_pages false  # Only show on first page of group

  # Group header elements...
end
```

**Options:**
- `repeat_on_pages: true` (default for `:page_header` and `:group_header`) - Header appears on every page
- `repeat_on_pages: false` - Header appears only on the first page

> **Note**: The `repeat_on_pages` option only applies to `:page_header` and `:group_header` band types.

## Column-Based Layout

AshReports uses a column-based layout system that leverages Typst's native `table()` function for clean, maintainable report definitions.

### Basic Column Layout

Define columns at the band level and assign elements to specific columns:

```elixir
band :customer_detail do
  type :detail
  columns 3  # Three equal-width columns

  field :name do
    source :customer_name
    column 0  # First column (zero-indexed)
  end

  field :score do
    source :health_score
    column 1  # Second column
  end

  field :tier do
    source :tier_name
    column 2  # Third column
  end
end
```

### Explicit Column Widths

For precise control, use Typst column width specifications:

```elixir
band :column_header do
  type :column_header
  columns "(150pt, 1fr, 80pt)"  # Explicit widths

  label :name_header do
    text "Customer Name"
    column 0
    style font_weight: :bold
  end

  label :score_header do
    text "Health Score"
    column 1
    style font_weight: :bold
  end

  label :tier_header do
    text "Tier"
    column 2
    style font_weight: :bold
  end
end
```

**Supported Column Width Units:**
- `150pt` - Fixed pixel width
- `1fr` - Fractional (proportional) sizing
- `auto` - Content-determined width
- `30%` - Percentage of page width
- `100%` - Full page width (default for single columns)

### Column Defaults and Auto-Assignment

**Single Column Behavior:**
When a band has a single column (or `columns` is not specified), it automatically uses the full page width:

```elixir
band :title do
  type :title
  # No columns specified - defaults to full page width

  label :report_title do
    text "Customer Report"
    # No column specified - uses column 0
  end
end
```

**Auto-Assignment:**
Elements without an explicit `column` attribute are automatically assigned sequential columns starting from 0:

```elixir
band :detail do
  type :detail
  columns 3

  field :name do
    source :name
    # Auto-assigned to column 0
  end

  field :score do
    source :score
    # Auto-assigned to column 1
  end

  field :tier do
    source :tier
    # Auto-assigned to column 2
  end
end
```

### Matching Column Widths

Ensure column widths match between related bands (e.g., headers and details):

```elixir
# Column header with explicit widths
band :column_header do
  type :column_header
  columns "(150pt, 100pt, 80pt)"

  label :name_header do
    text "Customer Name"
    column 0
  end

  label :score_header do
    text "Score"
    column 1
  end

  label :tier_header do
    text "Tier"
    column 2
  end
end

# Detail band with matching widths
band :customer_detail do
  type :detail
  columns "(150pt, 100pt, 80pt)"  # Must match header

  field :customer_name do
    source :name
    column 0
  end

  field :health_score do
    source :score
    column 1
  end

  field :tier_name do
    source :tier
    column 2
  end
end
```

**Key Points:**
- Columns are **zero-indexed** (0 = first column, 1 = second, etc.)
- Empty columns render as blank table cells
- Styling (font, color, alignment) is preserved in column layout
- Single columns automatically use full page width (100%)
- Multiple columns use equal width distribution unless explicit widths are provided

## Element Styling

Elements within columns support various styling options for formatting and appearance.

### Style Properties

```elixir
label :styled_label do
  text "Styled Text"
  column 0

  style(
    font_size: 16,
    font_weight: :bold,      # :normal or :bold
    font_style: :italic,     # :normal or :italic
    color: "#333333",
    background_color: "#f5f5f5",
    text_align: :center,     # :left, :center, :right, :justify
    vertical_align: :middle  # :top, :middle, :bottom
  )
end
```

### Styled Fields

```elixir
band :detail do
  type :detail
  columns "(150pt, 100pt, 80pt)"

  field :customer_name do
    source :name
    column 0
    style font_size: 14, font_weight: :bold
  end

  field :health_score do
    source :score
    column 1
    style text_align: :center, color: "#10B981"
  end

  field :tier do
    source :tier
    column 2
    style font_weight: :bold, text_align: :right
  end
end
```

**Available Style Options:**
- `font_size` - Integer (e.g., 12, 14, 16)
- `font_weight` - `:normal` or `:bold`
- `font_style` - `:normal` or `:italic`
- `color` - Hex color string (e.g., "#333333")
- `background_color` - Hex color string
- `text_align` - `:left`, `:center`, `:right`, or `:justify`
- `vertical_align` - `:top`, `:middle`, or `:bottom`

## Planned Advanced Features

The following advanced features are planned but not yet implemented. See [ROADMAP.md](../../ROADMAP.md) for complete details and timelines.

### Phase 3: Advanced Internationalization
- Dynamic locale switching per element
- RTL language support with automatic layout mirroring
- Gettext integration for translatable strings
- Multi-currency conversion
- Calendar system selection

### Phase 4: Performance and Optimization
- Report-level streaming configuration DSL
- Multi-level caching (query, report, chart)
- Performance monitoring and thresholds
- Auto-optimization based on metrics

### Phase 5: Security and Compliance
- Row-level security with dynamic scopes
- Field-level security and masking
- Data anonymization
- Audit logging
- Conditional visibility based on permissions

### Phase 6: Monitoring and Telemetry
- Performance monitoring DSL
- Alert configuration
- Auto-optimization triggers
- Detailed metrics collection

### Phase 7: Advanced Formatting
- Expression-based conditional formatting
- Statistical formatting (z-scores, percentiles)
- Custom format functions
- Advanced styling and themes

### Phase 8: Custom Extensions
- Custom element types
- Custom renderers for new formats
- Extension hooks
- Plugin system

### Example of Planned Security Features (NOT AVAILABLE)

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 5

report :secure_financial_report do
  driving_resource MyApp.Transaction

  # Row-level security
  scope expr(
    case get_user_role(^user_id) do
      :admin -> true
      :manager -> department == get_user_department(^user_id)
      _ -> false
    end
  )

  # Field-level security
  security do
    field_security do
      field :account_number do
        visible has_permission?(^user_id, :view_pii)
        mask_pattern "****-####"
      end
    end

    audit_access true
    log_user_id ^user_id
  end

  # Data masking
  data_masking do
    masking_rules do
      rule :customer_name do
        levels %{
          1 => mask_pattern("X****** X******"),
          2 => :no_mask
        }
        apply_level ^user_clearance
      end
    end
  end
end
```

### Example of Planned Performance Features (NOT AVAILABLE)

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 4

report :optimized_report do
  # Performance configuration
  performance do
    cache_duration 300
    streaming true
    parallel_processing true
    max_memory_usage "500MB"
  end

  # Streaming configuration
  streaming do
    enabled true
    chunk_size 1000
    buffer_size 10
    gc_frequency 1000
  end

  # Monitoring
  monitoring do
    thresholds do
      generation_time_warning 10_000
      memory_usage_warning "500MB"
    end

    auto_optimization do
      stream_threshold 5_000
      decimal_precision 2
    end

    alerts do
      on_slow_generation &MyApp.handle_slow_report/2
    end
  end
end
```

### Example of Planned Caching Features (NOT AVAILABLE)

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 4

report :cached_report do
  cache do
    # Report-level cache
    report_cache ttl: :timer.hours(1),
                 key: fn params -> "report_#{params.year}" end

    # Query result cache
    query_cache ttl: :timer.minutes(15),
                invalidate_on: [:invoice_created, :invoice_updated]
  end

  band :expensive_band do
    # Band-level caching
    cache_key fn params, context ->
      "band_#{params.year}_#{context.user_id}"
    end
    cache_ttl :timer.hours(2)
  end
end
```

## Best Practices

### Current Best Practices

1. **Use Format Specifications**: Define format specs once, reuse everywhere
2. **Consistent Positioning**: Use a grid system for element positioning
3. **Conditional Logic**: Use conditional visibility to simplify reports
4. **Styling**: Apply consistent styling through style properties
5. **Band Organization**: Organize bands in logical flow

### Performance Tips

1. **Limit Preloading**: Only preload relationships you use
2. **Database Indexes**: Add indexes on group/sort fields
3. **Aggregate Efficiently**: Use database aggregates when possible
4. **Test with Real Data**: Always test with production-like data volumes

### Maintainability

1. **Clear Naming**: Use descriptive names for reports, bands, elements
2. **Document Parameters**: Clearly document what each parameter does
3. **Consistent Formatting**: Stick to defined format specifications
4. **Version Control**: Treat report definitions as code

## Troubleshooting

### Common Issues

**Formatting not applying:**
- Verify format_spec name matches reference
- Check format type matches data type
- Ensure locale/currency values are valid

**Conditional visibility issues:**
- Verify expression syntax
- Check that referenced fields exist
- Test expressions with sample data

**Performance issues:**
- Check for missing database indexes
- Review preload strategy
- Consider data volume and complexity

**Layout problems:**
- Verify positioning doesn't cause overlaps
- Check can_grow/can_shrink settings
- Test with various data volumes

## See Also

- [ROADMAP.md](../../ROADMAP.md) - Complete feature roadmap
- [Report Creation Guide](report-creation.md) - Building reports
- [Integration Guide](integration.md) - Phoenix and LiveView integration
- [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) - Current status

## Next Steps

1. Review [ROADMAP.md](../../ROADMAP.md) to see planned advanced features
2. Check [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current implementation status
3. Build reports using currently available features
4. Watch for updates as advanced features are implemented
