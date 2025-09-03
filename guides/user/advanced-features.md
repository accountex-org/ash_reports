# Advanced Features

This guide covers advanced AshReports features including internationalization, performance optimization, security, caching, and complex formatting patterns.

## Table of Contents

- [Internationalization (i18n)](#internationalization-i18n)
- [Performance Optimization](#performance-optimization)
- [Security and Permissions](#security-and-permissions)
- [Caching Strategies](#caching-strategies)
- [Advanced Formatting](#advanced-formatting)
- [Custom Extensions](#custom-extensions)
- [Monitoring and Telemetry](#monitoring-and-telemetry)
- [Advanced Data Processing](#advanced-data-processing)

## Internationalization (i18n)

AshReports provides comprehensive internationalization support through CLDR integration, supporting multiple locales, currencies, and text directions including RTL languages.

### Locale Configuration

```elixir
# Configure supported locales in your application
config :ash_reports, AshReports.Cldr,
  default_locale: "en",
  locales: ["en", "es", "fr", "de", "ar", "he", "zh", "ja"],
  providers: [Cldr.Calendar, Cldr.Currency, Cldr.DateTime, Cldr.Number],
  generate_docs: false

# Set up gettext for text translations
config :ash_reports, AshReportsWeb.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de ar he zh ja)
```

### Locale-Aware Reports

```elixir
report :multilingual_sales_report do
  title "Sales Report"  # Will be translated based on locale
  description "Monthly sales analysis with international formatting"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :locale, :string, default: "en"
    parameter :currency, :atom, default: :USD
    parameter :start_date, :date, required: true
    parameter :end_date, :date, required: true
  end
  
  format_specs do
    # Locale-aware currency formatting
    format_spec :localized_currency do
      pattern "¤ #,##0.00"
      currency ^currency  # Use parameter
      locale ^locale      # Use parameter
    end
    
    # Locale-aware date formatting
    format_spec :localized_date do
      type :date
      locale ^locale
      pattern "long"  # Use CLDR long date format
    end
    
    # Locale-aware number formatting
    format_spec :localized_number do
      type :number
      locale ^locale
      pattern "#,##0.##"
    end
  end
  
  bands do
    band :title do
      type :title
      elements do
        # Translatable title
        label :report_title do
          text gettext("Sales Report")
          style font_size: 18, font_weight: :bold
        end
        
        # Locale-aware date range
        expression :date_range do
          expression expr(
            gettext("From") <> " " <> 
            AshReports.Formatter.format_date(^start_date, ^locale) <>
            " " <> gettext("to") <> " " <>
            AshReports.Formatter.format_date(^end_date, ^locale)
          )
        end
      end
    end
    
    band :column_headers do
      type :column_header
      elements do
        label :date_header do
          text gettext("Date")
          style font_weight: :bold
        end
        
        label :customer_header do
          text gettext("Customer")  
          style font_weight: :bold
        end
        
        label :amount_header do
          text gettext("Amount")
          style font_weight: :bold
        end
        
        label :status_header do
          text gettext("Status")
          style font_weight: :bold
        end
      end
    end
    
    band :details do
      type :detail
      elements do
        field :invoice_date do
          source :date
          format_spec :localized_date
        end
        
        field :customer_name do
          source :customer.name
        end
        
        field :total_amount do
          source :total
          format_spec :localized_currency
        end
        
        field :status_display do
          source :status
          conditional_format [
            {expr(status == :paid), [text: gettext("Paid"), color: :green]},
            {expr(status == :overdue), [text: gettext("Overdue"), color: :red]},
            {expr(status == :sent), [text: gettext("Sent"), color: :blue]}
          ]
        end
      end
    end
    
    band :summary do
      type :summary
      elements do
        label :total_label do
          text gettext("Grand Total:")
          style font_weight: :bold
        end
        
        aggregate :grand_total do
          function :sum
          source :total
          scope :report
          format_spec :localized_currency
          style font_weight: :bold
        end
      end
    end
  end
end
```

### RTL Language Support

```elixir
report :arabic_financial_report do
  title "التقرير المالي الشهري"  # Arabic title
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :locale, :string, default: "ar"
    parameter :currency, :atom, default: :AED
  end
  
  # RTL-specific formatting
  format_specs do
    format_spec :arabic_currency do
      pattern "¤ #,##0.00"
      currency :AED
      locale "ar"
      text_direction "rtl"
    end
    
    format_spec :arabic_date do
      type :date
      locale "ar"
      calendar "islamic"  # Islamic calendar
    end
  end
  
  bands do
    band :title do
      type :title
      elements do
        label :arabic_title do
          text "التقرير المالي الشهري"
          style font_size: 18, font_weight: :bold, 
                text_direction: :rtl, font_family: "Arial Unicode MS"
        end
      end
    end
    
    band :details do
      type :detail
      elements do
        # RTL-aware field positioning (right-to-left)
        field :customer_name do
          source :customer.name
          position x: 60, y: 0, width: 40, height: 12  # Right side
          style text_direction: :rtl, text_align: :right
        end
        
        field :amount do
          source :total
          format_spec :arabic_currency
          position x: 20, y: 0, width: 20, height: 12  # Middle-right
          style text_align: :right
        end
        
        field :date do
          source :date
          format_spec :arabic_date
          position x: 0, y: 0, width: 20, height: 12   # Left side
          style text_align: :right
        end
      end
    end
  end
end
```

### Multi-Currency Support

```elixir
report :multi_currency_report do
  title "Multi-Currency Financial Report"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :base_currency, :atom, default: :USD
    parameter :display_currencies, {:array, :atom}, default: [:USD, :EUR, :GBP]
  end
  
  format_specs do
    # Dynamic currency format specs
    format_spec :primary_currency do
      currency ^base_currency
      locale "en"
    end
    
    format_spec :converted_currency do
      # This would integrate with currency conversion service
      currency ^display_currency
      locale "en"
    end
  end
  
  variables do
    variable :conversion_rates do
      type :custom
      expression expr(
        # Fetch conversion rates from external service
        AshReports.CurrencyConverter.get_rates(^base_currency, ^display_currencies)
      )
      reset_on :report
    end
  end
  
  bands do
    band :details do
      type :detail
      elements do
        field :amount_base do
          source :total
          format_spec :primary_currency
          position x: 0, y: 0, width: 20, height: 12
        end
        
        # Show converted amounts for each display currency
        expression :amount_eur do
          expression expr(
            total * variable(:conversion_rates)[^:EUR]
          )
          format currency: :EUR
          position x: 20, y: 0, width: 20, height: 12
          conditional expr(:EUR in ^display_currencies)
        end
        
        expression :amount_gbp do
          expression expr(
            total * variable(:conversion_rates)[^:GBP]
          )
          format currency: :GBP
          position x: 40, y: 0, width: 20, height: 12
          conditional expr(:GBP in ^display_currencies)
        end
      end
    end
  end
end
```

## Performance Optimization

### Query Optimization

```elixir
report :optimized_large_dataset_report do
  title "High-Performance Large Dataset Report"
  driving_resource MyApp.Invoice
  
  # Pre-filter at database level
  scope expr(
    status != :cancelled and 
    date >= ^Date.add(Date.utc_today(), -365)  # Last year only
  )
  
  parameters do
    parameter :batch_size, :integer, default: 1000
    parameter :use_streaming, :boolean, default: true
  end
  
  # Optimize data loading
  preload [
    :customer,
    :line_items,
    line_items: [:product]
  ]
  
  # Use database aggregations instead of application-level calculations
  aggregations do
    # Pre-calculate at database level
    aggregate :monthly_totals, {:group_by, :month}, {:sum, :total}
    aggregate :customer_totals, {:group_by, :customer_id}, {:sum, :total}
    aggregate :product_totals, {:group_by, "line_items.product_id"}, {:sum, "line_items.line_total"}
  end
  
  bands do
    band :summary do
      type :summary
      elements do
        # Use pre-calculated aggregations
        expression :monthly_summary do
          expression aggregation(:monthly_totals)
          format :json  # Efficient serialization
        end
        
        # Paginated detail section for large datasets
        field :customer_totals do
          source aggregation(:customer_totals)
          pagination enabled: true, page_size: ^batch_size
        end
      end
    end
  end
  
  # Performance hints
  performance do
    cache_duration 300  # Cache for 5 minutes
    streaming ^use_streaming
    parallel_processing true
    max_memory_usage "500MB"
  end
end
```

### Streaming and Pagination

```elixir
report :streaming_report do
  title "Streaming Large Dataset Report"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :page_size, :integer, default: 100
    parameter :enable_streaming, :boolean, default: true
  end
  
  # Configure streaming behavior
  streaming do
    enabled ^enable_streaming
    chunk_size ^page_size
    buffer_size 10  # Keep 10 chunks in memory
    
    # Progress callbacks for long-running reports
    on_progress fn progress ->
      AshReports.ProgressTracker.update(progress.report_id, progress.percentage)
    end
    
    # Memory management
    max_memory "1GB"
    gc_frequency 1000  # Garbage collect every 1000 records
  end
  
  bands do
    band :details do
      type :detail
      
      # Streaming configuration at band level
      streaming_config do
        batch_size ^page_size
        prefetch 2  # Prefetch 2 batches ahead
      end
      
      elements do
        field :invoice_number do
          source :invoice_number
        end
        
        field :amount do
          source :total
          format :currency
        end
      end
    end
  end
end
```

### Caching Configuration

```elixir
# Application configuration
config :ash_reports,
  cache: [
    # ETS cache for compiled reports
    compiled_reports: [
      adapter: AshReports.Cache.ETS,
      ttl: :timer.hours(24),
      max_size: 1000
    ],
    
    # Redis cache for generated reports  
    generated_reports: [
      adapter: AshReports.Cache.Redis,
      ttl: :timer.minutes(30),
      key_prefix: "ash_reports:",
      serializer: :erlang
    ],
    
    # Database cache for expensive queries
    query_cache: [
      adapter: AshReports.Cache.Database,
      ttl: :timer.minutes(15),
      table: "report_query_cache"
    ]
  ]

# Report-level caching
report :cached_expensive_report do
  title "Expensive Analytics Report"
  driving_resource MyApp.Invoice
  
  # Cache configuration
  cache do
    # Cache the entire report for 1 hour
    report_cache ttl: :timer.hours(1), 
                 key: fn params -> "expensive_report_#{params.year}_#{params.quarter}" end
    
    # Cache query results for 15 minutes  
    query_cache ttl: :timer.minutes(15),
                invalidate_on: [:invoice_created, :invoice_updated]
    
    # Cache chart data separately
    chart_cache ttl: :timer.minutes(30)
  end
  
  parameters do
    parameter :year, :integer, default: Date.utc_today().year
    parameter :quarter, :integer
  end
  
  bands do
    band :expensive_analytics do
      type :detail
      
      # Band-level caching
      cache_key fn params, context -> 
        "analytics_#{params.year}_#{params.quarter}_#{context.user_id}"
      end
      
      elements do
        # Expensive calculation cached separately
        expression :complex_metric do
          expression expr(
            # Very expensive calculation
            AshReports.Analytics.calculate_complex_metric(
              year: ^year, 
              quarter: ^quarter
            )
          )
          cache ttl: :timer.hours(2)  # Cache this calculation for 2 hours
        end
      end
    end
  end
end
```

## Security and Permissions

### Row-Level Security

```elixir
report :secure_financial_report do
  title "Financial Report with Row-Level Security"
  driving_resource MyApp.Invoice
  
  # Base permissions required
  permissions [:view_financial_reports, :access_invoice_data]
  
  parameters do
    parameter :user_id, :uuid, required: true
    parameter :department_filter, :string
  end
  
  # Apply security scope based on user permissions
  scope expr(
    # Users can only see their own data or department data
    case get_user_role(^user_id) do
      :admin -> true  # Admins see everything
      :manager -> customer.department == get_user_department(^user_id)
      :sales_rep -> customer.assigned_rep_id == ^user_id
      _ -> false  # No access for others
    end
  )
  
  # Additional security filters
  security do
    # Mask sensitive data based on permissions
    field_security do
      field :customer_ssn do
        visible has_permission?(^user_id, :view_pii)
        mask_pattern "XXX-XX-####" unless has_permission?(^user_id, :view_full_ssn)
      end
      
      field :customer_credit_score do
        visible has_permission?(^user_id, :view_credit_info)
      end
    end
    
    # Audit all report access
    audit_access true
    log_user_id ^user_id
    log_fields [:report_name, :parameters, :execution_time, :record_count]
  end
  
  bands do
    band :details do
      type :detail
      elements do
        field :customer_name do
          source :customer.name
        end
        
        field :amount do
          source :total
          format :currency
          # Conditional masking
          conditional_format [
            {expr(not has_permission?(^user_id, :view_amounts)), 
             [text: "****", color: :gray]}
          ]
        end
        
        # Only show sensitive fields if authorized
        field :credit_score do
          source :customer.credit_score
          conditional expr(has_permission?(^user_id, :view_credit_info))
        end
      end
    end
  end
end
```

### Data Masking and Anonymization

```elixir
report :anonymized_customer_report do
  title "Anonymized Customer Analysis"
  driving_resource MyApp.Customer
  
  parameters do
    parameter :anonymization_level, :atom, default: :partial
    parameter :user_clearance, :integer, default: 1
  end
  
  # Data masking configuration
  data_masking do
    # Configure masking rules based on clearance level
    masking_rules do
      rule :customer_name do
        levels %{
          1 => mask_pattern("X****** X******"),  # Low clearance
          2 => mask_pattern("******* XXXXXX"),   # Medium clearance  
          3 => :no_mask                          # High clearance
        }
        apply_level ^user_clearance
      end
      
      rule :email do
        levels %{
          1 => mask_pattern("*****@*****.***"),
          2 => mask_pattern("*****@domain.com"),
          3 => :no_mask
        }
        apply_level ^user_clearance
      end
      
      rule :phone do
        levels %{
          1 => mask_pattern("***-***-****"),
          2 => mask_pattern("***-***-1234"),
          3 => :no_mask
        }
        apply_level ^user_clearance
      end
    end
    
    # Anonymization for aggregated data
    anonymization do
      # Add noise to prevent identification
      add_noise to: :revenue, variance: 0.05  # ±5% noise
      
      # Suppress small groups  
      suppress_groups smaller_than: 10
      
      # K-anonymity
      k_anonymity k: 5, quasi_identifiers: [:age_group, :region, :industry]
    end
  end
  
  bands do
    band :details do
      type :detail
      elements do
        field :masked_name do
          source :name
          apply_masking :customer_name
        end
        
        field :masked_email do
          source :email
          apply_masking :email
        end
        
        field :anonymized_revenue do
          source :total_revenue
          apply_anonymization :revenue
        end
        
        # Geographic aggregation to preserve privacy
        expression :region_group do
          expression expr(
            case region do
              r when r in ["CA", "OR", "WA"] -> "West Coast"
              r when r in ["NY", "NJ", "CT"] -> "Northeast"
              _ -> "Other"
            end
          )
        end
      end
    end
  end
end
```

## Advanced Formatting

### Complex Conditional Formatting

```elixir
format_specs do
  # Multi-level conditional formatting
  format_spec :performance_indicator do
    conditions [
      # Excellent performance
      {expr(value > 150000 and growth_rate > 0.15), [
        text: "🏆 Exceptional", 
        color: :gold, 
        background_color: "#1e3a8a",
        font_weight: :bold,
        border: "2px solid gold"
      ]},
      
      # Good performance  
      {expr(value > 100000 and growth_rate > 0.10), [
        text: "⭐ Excellent",
        color: :green,
        font_weight: :bold
      ]},
      
      # Average performance
      {expr(value > 50000 or growth_rate > 0.05), [
        text: "👍 Good",
        color: :blue
      ]},
      
      # Needs attention
      {expr(value > 10000), [
        text: "⚠️ Needs Attention", 
        color: :orange,
        font_style: :italic
      ]},
      
      # Critical
      {expr(value <= 10000 or growth_rate < -0.05), [
        text: "🚨 Critical",
        color: :red,
        background_color: :yellow,
        font_weight: :bold,
        animation: :blink
      ]}
    ]
    
    default [text: "📊 Standard", color: :gray]
  end
  
  # Progressive formatting based on ranges
  format_spec :revenue_tiers do
    type :currency
    currency :USD
    
    # Color coding based on value ranges
    conditions [
      {expr(value >= 1000000), [color: "#1e40af", prefix: "💎 "]},  # Diamond tier
      {expr(value >= 500000), [color: "#059669", prefix: "🥇 "]},    # Gold tier
      {expr(value >= 100000), [color: "#d97706", prefix: "🥈 "]},    # Silver tier
      {expr(value >= 50000), [color: "#dc2626", prefix: "🥉 "]},     # Bronze tier
      {expr(value > 0), [color: "#6b7280", prefix: "📈 "]}           # Standard tier
    ]
  end
  
  # Dynamic formatting based on statistical analysis
  format_spec :statistical_formatting do
    # Calculate statistics on the fly
    calculate_stats true
    
    conditions [
      # Outliers (beyond 2 standard deviations)
      {expr(abs(value - mean()) > 2 * std_dev()), [
        color: :red,
        font_weight: :bold,
        prefix: "🔴 "
      ]},
      
      # Above 75th percentile
      {expr(value > percentile(75)), [
        color: :green,
        prefix: "📈 "
      ]},
      
      # Below 25th percentile
      {expr(value < percentile(25)), [
        color: :orange,
        prefix: "📉 "
      ]}
    ]
  end
end
```

### Custom Format Functions

```elixir
# Define custom formatting functions
defmodule MyApp.CustomFormatters do
  @moduledoc "Custom formatting functions for AshReports"
  
  def format_business_size(revenue) when is_number(revenue) do
    cond do
      revenue > 1_000_000 -> "🏢 Enterprise"
      revenue > 100_000 -> "🏪 Medium Business"
      revenue > 10_000 -> "🏬 Small Business"
      true -> "🏠 Micro Business"
    end
  end
  
  def format_trend_arrow(current, previous) do
    change = (current - previous) / previous * 100
    
    cond do
      change > 20 -> "📈📈 Strong Growth (#{Float.round(change, 1)}%)"
      change > 5 -> "📈 Growth (#{Float.round(change, 1)}%)"
      change > -5 -> "➡️ Stable (#{Float.round(change, 1)}%)"
      change > -20 -> "📉 Decline (#{Float.round(change, 1)}%)"
      true -> "📉📉 Strong Decline (#{Float.round(change, 1)}%)"
    end
  end
  
  def format_customer_lifetime_value(clv) do
    case clv do
      clv when clv > 10000 -> "💎 VIP (#{format_currency(clv)})"
      clv when clv > 5000 -> "⭐ Premium (#{format_currency(clv)})"
      clv when clv > 1000 -> "👤 Standard (#{format_currency(clv)})"
      _ -> "👥 Basic (#{format_currency(clv)})"
    end
  end
  
  defp format_currency(amount) do
    "$#{:erlang.float_to_binary(amount / 1.0, decimals: 0)}"
  end
end

# Use custom formatters in reports
format_specs do
  format_spec :business_classification do
    custom_formatter &MyApp.CustomFormatters.format_business_size/1
  end
  
  format_spec :trend_analysis do  
    custom_formatter fn %{current: current, previous: previous} ->
      MyApp.CustomFormatters.format_trend_arrow(current, previous)
    end
  end
end
```

## Custom Extensions

### Custom Element Types

```elixir
defmodule MyApp.Reports.Elements.QRCode do
  @moduledoc "QR Code element for AshReports"
  
  use AshReports.Element
  
  defstruct [
    :name,
    :data_source,  # What to encode in QR code
    :size,         # QR code size
    :error_correction,  # Error correction level
    :position,
    :style
  ]
  
  @impl true
  def render(%__MODULE__{} = element, context, data) do
    qr_data = evaluate_data_source(element.data_source, context, data)
    
    # Generate QR code
    qr_code = :qrcode.encode(qr_data, element.error_correction || :medium)
    qr_image = :qrcode_png.simple_png(qr_code, element.size || 100)
    
    # Return rendered element
    %AshReports.RenderedElement{
      type: :qr_code,
      content: qr_image,
      position: element.position,
      metadata: %{
        data: qr_data,
        format: :png
      }
    }
  end
  
  @impl true
  def validate(%__MODULE__{} = element) do
    with :ok <- validate_required_fields(element, [:name, :data_source]),
         :ok <- validate_position(element.position),
         :ok <- validate_size(element.size) do
      :ok
    end
  end
  
  defp validate_size(size) when is_integer(size) and size > 0, do: :ok
  defp validate_size(nil), do: :ok  # Will use default
  defp validate_size(_), do: {:error, "Size must be a positive integer"}
end

# DSL integration
defmodule MyApp.Reports.CustomDsl do
  def qr_code_element_entity do
    %Spark.Dsl.Entity{
      name: :qr_code,
      describe: "A QR code element that encodes data",
      target: MyApp.Reports.Elements.QRCode,
      args: [:name],
      schema: [
        name: [type: :atom, required: true],
        data_source: [type: :any, required: true],
        size: [type: :pos_integer, default: 100],
        error_correction: [type: {:in, [:low, :medium, :high, :highest]}, default: :medium],
        position: [type: :keyword_list, default: []],
        style: [type: :keyword_list, default: []]
      ]
    }
  end
end

# Usage in reports
bands do
  band :invoice_footer do
    type :page_footer
    elements do
      # Custom QR code element
      qr_code :invoice_qr do
        data_source expr("INVOICE:" <> invoice_number <> ":TOTAL:" <> to_string(total))
        size 150
        error_correction :high
        position x: 80, y: 0, width: 20, height: 20
      end
    end
  end
end
```

### Custom Renderers

```elixir
defmodule MyApp.Reports.Renderers.SlackRenderer do
  @moduledoc "Custom Slack renderer for AshReports"
  
  @behaviour AshReports.Renderer
  
  @impl true
  def render(report, context, data) do
    slack_blocks = 
      report.bands
      |> Enum.map(&render_band(&1, context, data))
      |> List.flatten()
    
    slack_message = %{
      "blocks" => slack_blocks,
      "text" => report.title
    }
    
    {:ok, Jason.encode!(slack_message)}
  end
  
  defp render_band(band, context, data) do
    case band.type do
      :title -> render_title_band(band, context, data)
      :detail -> render_detail_band(band, context, data)
      :summary -> render_summary_band(band, context, data)
      _ -> []
    end
  end
  
  defp render_title_band(band, _context, _data) do
    title_element = Enum.find(band.elements, &(&1.type == :label))
    
    if title_element do
      [%{
        "type" => "header",
        "text" => %{
          "type" => "plain_text",
          "text" => title_element.text
        }
      }]
    else
      []
    end
  end
  
  defp render_detail_band(band, context, data) do
    # Convert detail rows to Slack table format
    fields = Enum.map(band.elements, fn element ->
      %{
        "type" => "mrkdwn",
        "text" => "*#{element.name}:*\n#{format_element_value(element, context, data)}"
      }
    end)
    
    [%{
      "type" => "section",
      "fields" => fields
    }]
  end
  
  defp render_summary_band(band, context, data) do
    summary_text = 
      band.elements
      |> Enum.map(&format_element_value(&1, context, data))
      |> Enum.join(" | ")
    
    [%{
      "type" => "section",
      "text" => %{
        "type" => "mrkdwn", 
        "text" => "*Summary:* #{summary_text}"
      }
    }]
  end
  
  defp format_element_value(element, context, data) do
    # Format based on element type and format specs
    value = AshReports.DataProcessor.evaluate_element(element, context, data)
    AshReports.Formatter.format_value(value, element.format || :text, context)
  end
end

# Register custom renderer
config :ash_reports, 
  renderers: %{
    slack: MyApp.Reports.Renderers.SlackRenderer,
    html: AshReports.HtmlRenderer,
    pdf: AshReports.PdfRenderer,
    json: AshReports.JsonRenderer,
    heex: AshReports.HeexRenderer
  }

# Usage
{:ok, slack_message} = AshReports.generate(
  MyApp.MyDomain, 
  :sales_summary, 
  %{month: 12}, 
  :slack
)
```

## Monitoring and Telemetry

### Telemetry Integration

```elixir
# Configure telemetry events
config :ash_reports,
  telemetry: [
    # Report generation events
    [:ash_reports, :report, :generation, :start],
    [:ash_reports, :report, :generation, :stop], 
    [:ash_reports, :report, :generation, :exception],
    
    # Query execution events
    [:ash_reports, :query, :execution, :start],
    [:ash_reports, :query, :execution, :stop],
    
    # Rendering events
    [:ash_reports, :render, :start],
    [:ash_reports, :render, :stop],
    
    # Chart generation events
    [:ash_reports, :chart, :generation, :start],
    [:ash_reports, :chart, :generation, :stop],
    
    # Cache events
    [:ash_reports, :cache, :hit],
    [:ash_reports, :cache, :miss]
  ]

# Telemetry handler
defmodule MyApp.Reports.TelemetryHandler do
  require Logger
  
  def handle_event([:ash_reports, :report, :generation, :start], measurements, metadata, _config) do
    Logger.info("Starting report generation", 
      report_name: metadata.report_name,
      user_id: metadata.user_id,
      parameters: inspect(metadata.parameters)
    )
  end
  
  def handle_event([:ash_reports, :report, :generation, :stop], measurements, metadata, _config) do
    Logger.info("Report generation completed",
      report_name: metadata.report_name,
      duration_ms: measurements.duration,
      record_count: metadata.record_count,
      cache_hit: metadata.cache_hit
    )
    
    # Send metrics to monitoring system
    :telemetry.execute([:myapp, :reports, :generated], %{count: 1}, metadata)
    
    # Track performance metrics
    if measurements.duration > 30_000 do  # > 30 seconds
      Logger.warn("Slow report generation detected",
        report_name: metadata.report_name,
        duration_ms: measurements.duration
      )
    end
  end
  
  def handle_event([:ash_reports, :report, :generation, :exception], _measurements, metadata, _config) do
    Logger.error("Report generation failed",
      report_name: metadata.report_name,
      error: inspect(metadata.error),
      stacktrace: Exception.format_stacktrace(metadata.stacktrace)
    )
  end
  
  def handle_event([:ash_reports, :cache, :hit], _measurements, metadata, _config) do
    :telemetry.execute([:myapp, :reports, :cache], %{hits: 1}, metadata)
  end
  
  def handle_event([:ash_reports, :cache, :miss], _measurements, metadata, _config) do
    :telemetry.execute([:myapp, :reports, :cache], %{misses: 1}, metadata)
  end
end

# Attach handlers
:telemetry.attach_many(
  "ash-reports-telemetry",
  [
    [:ash_reports, :report, :generation, :start],
    [:ash_reports, :report, :generation, :stop],
    [:ash_reports, :report, :generation, :exception],
    [:ash_reports, :cache, :hit],
    [:ash_reports, :cache, :miss]
  ],
  &MyApp.Reports.TelemetryHandler.handle_event/4,
  %{}
)
```

### Performance Monitoring

```elixir
report :monitored_report do
  title "Performance Monitored Report"
  driving_resource MyApp.Invoice
  
  # Performance monitoring configuration
  monitoring do
    # Set performance thresholds
    thresholds do
      generation_time_warning 10_000  # 10 seconds
      generation_time_critical 30_000  # 30 seconds
      memory_usage_warning "500MB"
      memory_usage_critical "1GB"
      record_count_warning 10_000
      record_count_critical 50_000
    end
    
    # Automatic performance optimizations
    auto_optimization do
      # Enable streaming for large datasets
      stream_threshold 5_000
      
      # Reduce precision for performance
      decimal_precision 2
      
      # Limit related data loading
      max_preload_depth 2
      
      # Enable query result caching
      query_cache_ttl :timer.minutes(15)
    end
    
    # Performance alerts
    alerts do
      # Slack notifications for slow reports
      slack_webhook System.get_env("SLACK_WEBHOOK_URL")
      
      # Email notifications for critical issues
      email_alerts ["admin@company.com"]
      
      # Custom alert handlers
      on_slow_generation &MyApp.Reports.AlertHandler.handle_slow_report/2
      on_memory_limit &MyApp.Reports.AlertHandler.handle_memory_limit/2
    end
  end
  
  bands do
    # Monitoring metadata in reports
    band :performance_footer do
      type :page_footer
      elements do
        expression :generation_time do
          expression expr("Generated in " <> to_string(generation_time_ms) <> "ms")
          style font_size: 8, color: :gray
        end
        
        expression :record_count do
          expression expr("Records processed: " <> to_string(record_count))
          style font_size: 8, color: :gray
        end
        
        expression :cache_status do
          expression expr(
            "Cache: " <> 
            if(cache_hit, "HIT", "MISS") <>
            " | Memory: " <> to_string(memory_usage_mb) <> "MB"
          )
          style font_size: 8, color: :gray
        end
      end
    end
  end
end
```

### Health Checks and Diagnostics

```elixir
defmodule MyApp.Reports.HealthCheck do
  @moduledoc "Health checks for AshReports system"
  
  def system_health do
    %{
      cache_status: check_cache_health(),
      database_connectivity: check_database(),
      renderer_status: check_renderers(),
      chart_engine_status: check_chart_engine(),
      memory_usage: check_memory_usage(),
      active_reports: count_active_reports()
    }
  end
  
  defp check_cache_health do
    try do
      AshReports.Cache.ping()
      %{status: :healthy, latency_ms: measure_cache_latency()}
    rescue
      _ -> %{status: :unhealthy, error: "Cache unreachable"}
    end
  end
  
  defp check_database do
    try do
      Ash.Query.new(MyApp.Invoice) |> Ash.Query.limit(1) |> MyApp.MyDomain.read()
      %{status: :healthy}
    rescue
      error -> %{status: :unhealthy, error: inspect(error)}
    end
  end
  
  defp check_renderers do
    renderers = [:html, :pdf, :json, :heex]
    
    results = 
      Enum.map(renderers, fn renderer ->
        try do
          # Test render a simple report
          test_report = create_test_report()
          AshReports.generate(MyApp.MyDomain, :health_check, %{}, renderer)
          {renderer, :healthy}
        rescue
          error -> {renderer, {:unhealthy, inspect(error)}}
        end
      end)
    
    Map.new(results)
  end
  
  defp check_chart_engine do
    try do
      config = %AshReports.ChartConfig{
        type: :line,
        data: [{1, 10}, {2, 20}],
        title: "Health Check"
      }
      
      context = %AshReports.RenderContext{locale: "en"}
      AshReports.ChartEngine.generate(config, context)
      
      %{status: :healthy}
    rescue
      error -> %{status: :unhealthy, error: inspect(error)}
    end
  end
  
  defp check_memory_usage do
    {:ok, memory_info} = :memsup.get_system_memory_data()
    total_memory = Keyword.get(memory_info, :total_memory, 0)
    free_memory = Keyword.get(memory_info, :available_memory, 0)
    used_percentage = ((total_memory - free_memory) / total_memory * 100) |> round()
    
    %{
      used_percentage: used_percentage,
      status: if(used_percentage > 90, do: :critical, else: :healthy)
    }
  end
  
  defp count_active_reports do
    # Count currently running report generation processes
    Process.list()
    |> Enum.count(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} -> 
          Keyword.get(dict, :ash_reports_generation, false)
        _ -> 
          false
      end
    end)
  end
  
  defp measure_cache_latency do
    start_time = :os.system_time(:millisecond)
    AshReports.Cache.get("health_check_key", fn -> "test_value" end)
    :os.system_time(:millisecond) - start_time
  end
  
  defp create_test_report do
    # Create a minimal test report for health checks
    %AshReports.Report{
      name: :health_check,
      title: "Health Check Report",
      driving_resource: MyApp.Invoice,
      formats: [:html, :pdf, :json, :heex],
      bands: [
        %AshReports.Band{
          name: :test_band,
          type: :title,
          elements: [
            %AshReports.Element.Label{
              name: :test_label,
              text: "System Healthy"
            }
          ]
        }
      ]
    }
  end
end
```

This advanced features guide demonstrates the enterprise-ready capabilities of AshReports, including comprehensive internationalization, performance optimization, security features, and monitoring capabilities that make it suitable for production use in complex applications.