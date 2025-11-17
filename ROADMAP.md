# AshReports Roadmap

This document outlines planned features and enhancements for AshReports that are not yet implemented but documented in our vision for the framework.

## Status Legend

- 🔵 **Planned** - Designed but not yet started
- 🟡 **In Progress** - Currently being implemented
- 🟢 **Completed** - Fully implemented and tested
- 🔴 **Blocked** - Waiting on dependencies or decisions

---

## Phase 1: Core Foundation (Current Phase)

### 🟢 Completed

- [x] Core DSL infrastructure with Spark
- [x] Band hierarchy system (11 band types)
- [x] Basic element types (label, field, expression, aggregate, line, box, image, chart)
- [x] Parameter and variable definitions
- [x] Format specification framework
- [x] Group-by functionality
- [x] Basic CLDR integration structure
- [x] Report validation and verification

### 🔴 Current Gaps

- [ ] Fully functional data loading pipeline
- [ ] Complete renderer implementations (HTML, PDF, JSON, HEEX)
- [ ] Integration testing of full report generation flow

---

## Phase 2: Enhanced Chart Engine

**Priority**: High
**Timeline**: Q2 2025
**Status**: 🔵 Planned

### Features

#### Chart Configuration System

```elixir
# Planned API
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: sales_data,
  title: "Monthly Sales Trend",
  provider: :chartjs,
  interactive: true,
  real_time: false
}

{:ok, chart} = AshReports.ChartEngine.generate(chart_config, render_context)
```

**Components**:
- `AshReports.ChartEngine` - Core chart generation module
- `AshReports.ChartConfig` - Chart configuration struct
- Multi-provider support (Chart.js, D3.js, Plotly)
- Provider-specific renderers

#### Auto Chart Selection

```elixir
# Automatically suggest appropriate chart types
suggestions = AshReports.ChartEngine.auto_select_charts(data, context)
# Returns: [
#   %ChartConfig{type: :line, confidence: 0.9, reasoning: "Time series data..."},
#   %ChartConfig{type: :bar, confidence: 0.8, reasoning: "Categorical comparison..."}
# ]
```

#### Interactive Charts

- Real-time data updates with configurable intervals
- Zoom and pan controls
- Interactive filtering
- Click/hover event handlers for LiveView integration
- Chart animations and transitions

#### Advanced Chart Types

- Histogram charts with configurable bins
- Box plot charts for statistical analysis
- Heatmaps for density visualization
- 3D surface plots (via Plotly provider)
- Custom D3.js visualizations

**Current Status**: Basic chart element exists with limited types (:bar, :line, :pie, :area, :scatter) via Contex integration.

---

## Phase 3: Advanced Internationalization

**Priority**: Medium
**Timeline**: Q3 2025
**Status**: 🔵 Planned

### Features

#### Enhanced CLDR Integration

```elixir
# Full locale-aware formatting at element level
field :amount do
  source :total
  format_spec :localized_currency
  locale ^locale_param  # Dynamic locale per-element
end

format_spec :localized_currency do
  pattern "¤ #,##0.00"
  currency ^currency_param
  locale ^locale_param
  text_direction ^text_direction  # :ltr or :rtl
end
```

#### RTL Language Support

- Automatic layout mirroring for RTL languages
- RTL-aware element positioning
- Font selection for RTL scripts
- Mixed LTR/RTL content handling
- Calendar system selection (Gregorian, Islamic, Hebrew, etc.)

#### Translation Integration

```elixir
# Integration with Gettext for translatable strings
label :title do
  text gettext("Sales Report")  # Translatable labels
end

# Multi-language report variants
report :sales_report do
  locale_variants [:en, :es, :fr, :ar, :he, :zh, :ja]
end
```

#### Multi-Currency Support

```elixir
# Real-time currency conversion
format_spec :multi_currency do
  base_currency :USD
  display_currencies [:EUR, :GBP, :JPY]
  conversion_service MyApp.CurrencyConverter
end
```

**Current Status**: Basic `locale` and `currency` options exist in format_spec schema. CLDR dependency present but minimal integration.

---

## Phase 4: Performance and Optimization

**Priority**: High
**Timeline**: Q2-Q3 2025
**Status**: 🔵 Planned

### Features

#### Report-Level Performance Configuration

```elixir
report :optimized_report do
  # Performance tuning
  performance do
    cache_duration 300  # seconds
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
    max_memory "1GB"
  end
end
```

#### Advanced Caching

```elixir
# Multi-level caching
report :cached_report do
  cache do
    # Report-level cache
    report_cache ttl: :timer.hours(1),
                 key: fn params -> "report_#{params.year}" end

    # Query result cache
    query_cache ttl: :timer.minutes(15),
                invalidate_on: [:invoice_created, :invoice_updated]

    # Chart data cache
    chart_cache ttl: :timer.minutes(30)
  end
end

# Band-level caching
band :expensive_analytics do
  cache_key fn params, context ->
    "analytics_#{params.year}_#{context.user_id}"
  end
  cache_ttl :timer.hours(2)
end
```

#### Database Query Optimization

- Pre-calculated aggregations at database level
- Configurable preload strategies
- Batch loading for relationships
- Query result streaming via Ash.stream! with keyset pagination

#### Memory Management

- Automatic memory monitoring
- Garbage collection hints
- Memory usage alerts
- Streaming for large datasets (partially implemented)

**Current Status**: Basic streaming mentioned in code but not fully implemented. No caching infrastructure.

---

## Phase 5: Security and Compliance

**Priority**: High
**Timeline**: Q3 2025
**Status**: 🔵 Planned

### Features

#### Row-Level Security

```elixir
report :secure_report do
  permissions [:view_financial_reports]

  # Dynamic scope based on user role
  scope expr(
    case get_user_role(^user_id) do
      :admin -> true
      :manager -> customer.department == get_user_department(^user_id)
      :sales_rep -> customer.assigned_rep_id == ^user_id
      _ -> false
    end
  )

  # Field-level security
  security do
    field_security do
      field :customer_ssn do
        visible has_permission?(^user_id, :view_pii)
        mask_pattern "XXX-XX-####"
      end
    end

    # Audit logging
    audit_access true
    log_user_id ^user_id
    log_fields [:report_name, :parameters, :execution_time]
  end
end
```

#### Data Masking and Anonymization

```elixir
report :anonymized_report do
  data_masking do
    masking_rules do
      rule :customer_name do
        levels %{
          1 => mask_pattern("X****** X******"),
          2 => mask_pattern("******* XXXXXX"),
          3 => :no_mask
        }
        apply_level ^user_clearance
      end
    end

    anonymization do
      add_noise to: :revenue, variance: 0.05
      suppress_groups smaller_than: 10
      k_anonymity k: 5, quasi_identifiers: [:age_group, :region]
    end
  end
end
```

#### Conditional Masking in Elements

```elixir
field :sensitive_data do
  source :credit_score
  conditional_format [
    {expr(not has_permission?(^user_id, :view_credit)),
     [text: "****", color: :gray]}
  ]
end
```

**Current Status**: No security features implemented in DSL.

---

## Phase 6: Monitoring and Telemetry

**Priority**: Medium
**Timeline**: Q4 2025
**Status**: 🔵 Planned

### Features

#### Performance Monitoring DSL

```elixir
report :monitored_report do
  monitoring do
    thresholds do
      generation_time_warning 10_000
      generation_time_critical 30_000
      memory_usage_warning "500MB"
      record_count_warning 10_000
    end

    auto_optimization do
      stream_threshold 5_000
      decimal_precision 2
      max_preload_depth 2
      query_cache_ttl :timer.minutes(15)
    end

    alerts do
      slack_webhook System.get_env("SLACK_WEBHOOK_URL")
      email_alerts ["admin@company.com"]
      on_slow_generation &MyApp.Reports.AlertHandler.handle_slow_report/2
    end
  end
end
```

#### Telemetry Events

- Report generation lifecycle events
- Query execution timing
- Rendering performance metrics
- Cache hit/miss rates
- Memory usage tracking
- Custom metric collection

#### Performance Metadata in Reports

```elixir
# Automatic performance footer
band :performance_footer do
  type :page_footer
  elements do
    expression :generation_time do
      expression expr("Generated in " <> to_string(generation_time_ms) <> "ms")
    end

    expression :cache_status do
      expression expr("Cache: " <> if(cache_hit, "HIT", "MISS"))
    end
  end
end
```

**Current Status**: No monitoring infrastructure implemented.

---

## Phase 7: Advanced Formatting

**Priority**: Low
**Timeline**: Q4 2025
**Status**: 🔵 Planned

### Features

#### Expression-Based Conditional Formatting

```elixir
format_spec :advanced_conditional do
  conditions [
    # Complex expressions in conditions
    {expr(value > 10000 and growth_rate > 0.15), [
      text: "🏆 Exceptional",
      color: :gold,
      background_color: "#1e3a8a",
      font_weight: :bold
    ]},
    {expr(value > 5000 or growth_rate > 0.10), [
      text: "⭐ Excellent",
      color: :green
    ]}
  ]
  fallback [text: "Standard", color: :gray]
end
```

#### Statistical Formatting

```elixir
format_spec :statistical do
  calculate_stats true

  conditions [
    {expr(abs(value - mean()) > 2 * std_dev()), [
      color: :red,
      prefix: "🔴 "
    ]},
    {expr(value > percentile(75)), [
      color: :green,
      prefix: "📈 "
    ]}
  ]
end
```

#### Custom Format Functions

```elixir
defmodule MyApp.CustomFormatters do
  def format_business_size(revenue) do
    cond do
      revenue > 1_000_000 -> "🏢 Enterprise"
      revenue > 100_000 -> "🏪 Medium Business"
      true -> "🏠 Micro Business"
    end
  end
end

format_spec :business_classification do
  custom_formatter &MyApp.CustomFormatters.format_business_size/1
end
```

**Current Status**: Basic format_spec exists with simple `conditions` keyword list, not expression-based.

---

## Phase 8: Custom Extensions

**Priority**: Low
**Timeline**: Q1 2026
**Status**: 🔵 Planned

### Features

#### Custom Element Types

```elixir
defmodule MyApp.Reports.Elements.QRCode do
  use AshReports.Element

  defstruct [:name, :data_source, :size, :error_correction, :position, :style]

  @impl true
  def render(%__MODULE__{} = element, context, data) do
    # Custom rendering logic
  end
end

# DSL registration
defmodule MyApp.Reports.CustomDsl do
  def qr_code_element_entity do
    %Spark.Dsl.Entity{
      name: :qr_code,
      target: MyApp.Reports.Elements.QRCode,
      # ...
    }
  end
end
```

#### Custom Renderers

```elixir
defmodule MyApp.Reports.Renderers.SlackRenderer do
  @behaviour AshReports.Renderer

  @impl true
  def render(report, context, data) do
    # Convert report to Slack blocks format
  end
end

# Register renderer
config :ash_reports,
  renderers: %{
    slack: MyApp.Reports.Renderers.SlackRenderer,
    html: AshReports.HtmlRenderer
  }
```

#### Extension Points

- Custom element types with DSL integration
- Custom renderers for new output formats
- Custom format functions
- Custom data sources
- Pre/post rendering hooks

**Current Status**: No extension API defined or documented.

---

## Phase 9: Integration Enhancements

**Priority**: Medium
**Timeline**: Q1 2026
**Status**: 🔵 Planned

### Features

#### Phoenix LiveView Enhancements

- Real-time report updates via LiveView
- Interactive parameter controls
- Drill-down navigation
- Export functionality
- Report caching for LiveView sessions

#### External System Integration

- Webhook notifications on report generation
- Slack integration for report delivery
- Email report distribution
- S3/cloud storage for large reports
- GraphQL API for report generation

#### Scheduled Reports

```elixir
# Cron-style report scheduling
schedule_params = %{
  report_name: :monthly_sales,
  schedule: "0 0 1 * *",  # First day of month
  parameters: %{...},
  format: :pdf,
  delivery: %{
    method: :email,
    recipients: ["sales@company.com"]
  }
}

{:ok, job} = AshReports.Scheduler.schedule_report(schedule_params)
```

**Current Status**: Basic LiveView integration mentioned but not fully implemented.

---

## Phase 10: Production Features

**Priority**: High
**Timeline**: Q2 2026
**Status**: 🔵 Planned

### Features

#### Health Checks

- System health monitoring endpoints
- Cache connectivity checks
- Database connectivity verification
- Renderer availability checks
- Memory usage monitoring

#### Error Recovery

- Automatic retry on transient failures
- Graceful degradation for missing features
- Detailed error messages with suggested fixes
- Error aggregation and reporting

#### Production Configuration

- Environment-specific settings
- Docker deployment support
- Kubernetes manifests
- Load balancing configuration
- Scaling guidelines

---

## Technical Debt and Quality Improvements

### Code Quality

- **Duplication Reduction**: Current 25% duplication → Target <10%
- **Test Coverage**: Current 40-50% → Target >80%
- **Documentation Coverage**: Current incomplete → Target 100% public API

### Architecture

- **Template Engine Abstraction**: Separate rendering logic from business logic
- **Dependency Injection**: Reduce tight coupling in renderers
- **Module Organization**: Better separation of concerns

### Security

- **Process Dictionary Removal**: Replace all process dictionary usage
- **Input Validation**: Comprehensive validation for all user inputs
- **Security Audit**: Third-party security review

---

## Community Features

**Priority**: Low
**Timeline**: Ongoing

### Documentation

- [ ] Video tutorials
- [ ] Interactive examples
- [ ] Recipe book for common patterns
- [ ] Migration guides

### Tooling

- [ ] Mix task for report generation
- [ ] Development dashboard
- [ ] Report designer UI
- [ ] Testing utilities

### Ecosystem

- [ ] Plugin system
- [ ] Community templates
- [ ] Chart type contributions
- [ ] Format renderer contributions

---

## Research and Exploration

These are ideas being explored but not yet committed to the roadmap:

### Potential Features

- **AI-Powered Report Generation**: Natural language to report DSL
- **Report Analytics**: Track report usage and performance
- **Collaborative Editing**: Multi-user report design
- **Version Control**: Report definition versioning
- **A/B Testing**: Report variant testing
- **Report Marketplace**: Share and discover report templates

---

## How to Contribute

Interested in helping implement these features? Here's how:

1. **Check the Status**: Look for 🔵 Planned items that interest you
2. **Open an Issue**: Discuss the feature before starting work
3. **Follow the Roadmap**: Implement features in priority order when possible
4. **Write Tests**: All features need comprehensive tests
5. **Update Documentation**: Document as you implement

For more details, see our [CONTRIBUTING.md](CONTRIBUTING.md) (coming soon).

---

## Feedback

Have ideas for features not listed here? Open a discussion at:
https://github.com/accountex-org/ash_reports/discussions

Want to prioritize a specific feature? Star the issue or add a comment explaining your use case.

---

**Last Updated**: 2025-01-XX
**Maintained By**: AshReports Core Team
**License**: MIT
