# AshReports Demo - Comprehensive User Guide

Welcome to the AshReports Demo Application! This guide provides detailed instructions for using both the interactive console (IEx) and web interface to explore the powerful reporting capabilities of the AshReports library.

## Table of Contents

1. [Getting Started](#getting-started)
2. [IEx Console Commands](#iex-console-commands)
3. [Web Interface Guide](#web-interface-guide)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [Report Types and Features](#report-types-and-features)
6. [Performance and Benchmarking](#performance-and-benchmarking)
7. [Troubleshooting](#troubleshooting)
8. [FAQ](#faq)

## Getting Started

### Prerequisites

- Elixir 1.18 or later
- Mix build tool
- Terminal access

### Installation and Setup

1. **Clone and Navigate**
   ```bash
   cd /path/to/ash_reports/demo
   ```

2. **Install Dependencies**
   ```bash
   mix deps.get
   ```

3. **Start the Application**
   ```bash
   # Option 1: Interactive Console (Recommended for first-time users)
   iex -S mix

   # Option 2: Web Interface
   mix phx.server
   # Then visit http://localhost:4000

   # Option 3: Quick Demo via Mix Task
   mix demo
   ```

## IEx Console Commands

The IEx console provides the most comprehensive access to all demo features. Below are all available commands organized by category.

### 🚀 Quick Start Commands

```elixir
# Start the guided interactive demo (recommended for beginners)
AshReportsDemo.start_demo()

# Run a quick automated demo without user interaction
AshReportsDemo.InteractiveDemo.quick_demo()
```

### 📊 Data Management Commands

#### Data Generation

```elixir
# Generate sample data with different volumes
AshReportsDemo.generate_sample_data(:small)   # 10 customers, 50 products, 25 invoices
AshReportsDemo.generate_sample_data(:medium)  # 100 customers, 200 products, 500 invoices
AshReportsDemo.generate_sample_data(:large)   # 1000 customers, 2000 products, 10000 invoices

# Quick generation (minimal logging)
AshReportsDemo.DataGenerator.quick_generate(:medium)
```

#### Data Inspection

```elixir
# Get comprehensive data summary
AshReportsDemo.data_summary()
# Returns: %{customers: 100, products: 200, invoices: 500, generated_at: ~U[...]}

# Validate data integrity and relationships
AshReportsDemo.DataGenerator.validate_data_integrity()

# Check demo system status
AshReportsDemo.DataGenerator.demo_status()

# Get detailed statistics
AshReportsDemo.DataGenerator.get_statistics()
```

#### Data Cleanup

```elixir
# Reset all demo data
AshReportsDemo.reset_data()

# Alternative direct call
AshReportsDemo.DataGenerator.reset_data()
```

### 📈 Report Execution Commands

#### List and Discover Reports

```elixir
# List all available reports
AshReportsDemo.list_reports()
# Returns: [:customer_summary, :product_inventory, :invoice_details, :financial_summary]

# Get detailed information about reports (if available)
AshReports.Info.reports(AshReportsDemo.Domain)
```

#### Basic Report Execution

```elixir
# Run reports in HTML format (default)
AshReportsDemo.run_report(:customer_summary, %{}, format: :html)
AshReportsDemo.run_report(:product_inventory, %{}, format: :html)
AshReportsDemo.run_report(:invoice_details, %{}, format: :html)
AshReportsDemo.run_report(:financial_summary, %{}, format: :html)

# Run reports in other formats
AshReportsDemo.run_report(:customer_summary, %{}, format: :json)
AshReportsDemo.run_report(:financial_summary, %{}, format: :pdf)   # If PDF enabled
```

#### Advanced Report Parameters

```elixir
# Financial reports with date range filtering
AshReportsDemo.run_report(:financial_summary, %{
  start_date: ~D[2024-01-01],
  end_date: ~D[2024-12-31]
}, format: :html)

# Customer reports with filtering
AshReportsDemo.run_report(:customer_summary, %{
  status: "active",
  min_total_orders: 100
}, format: :html)

# Product reports with inventory thresholds
AshReportsDemo.run_report(:product_inventory, %{
  category: "electronics",
  low_stock_threshold: 10
}, format: :html)
```

### ⚡ Performance and Benchmarking Commands

```elixir
# Run performance benchmarks with default settings
AshReportsDemo.benchmark_reports()

# Benchmark with specific data size
AshReportsDemo.benchmark_reports(data_size: :small)
AshReportsDemo.benchmark_reports(data_size: :medium)
AshReportsDemo.benchmark_reports(data_size: :large)

# Advanced benchmarking with custom options
AshReportsDemo.benchmark_reports(
  data_size: :large,
  formats: [:html, :json],
  iterations: 5
)
```

### 🔧 System and Diagnostic Commands

```elixir
# Check if PDF functionality is available
AshReports.Application.chromic_pdf_available?()

# Verify demo readiness
AshReportsDemo.DataGenerator.health_check()

# Get current GenServer state
:sys.get_state(AshReportsDemo.DataGenerator)

# Monitor memory usage
:erlang.memory()
```

### 🧪 Development and Testing Commands

```elixir
# Manual data validation
AshReportsDemo.DataGenerator.validate_relationships()

# Test specific report types
for report <- AshReportsDemo.list_reports() do
  case AshReportsDemo.run_report(report, %{}, format: :html) do
    {:ok, _} -> IO.puts("✅ #{report} - SUCCESS")
    {:error, reason} -> IO.puts("❌ #{report} - FAILED: #{reason}")
  end
end

# Generate and test with custom volumes
volumes = [:small, :medium, :large]
for volume <- volumes do
  AshReportsDemo.generate_sample_data(volume)
  stats = AshReportsDemo.data_summary()
  IO.inspect({volume, stats})
  AshReportsDemo.reset_data()
end
```

## Web Interface Guide

### Accessing the Web Interface

1. **Start the Phoenix Server**
   ```bash
   cd demo
   mix phx.server
   ```

2. **Open Your Browser**
   Navigate to: `http://localhost:4000`

### Web Interface Features

#### Main Dashboard (`/`)
- Overview of the AshReports demo system
- Quick access to report categories
- System status indicators

#### Reports Index (`/reports`)
- **Available Reports**: Browse all available report types
- **Regenerate Data Button**: Click to generate fresh sample data
- **Report Cards**: Each report shows:
  - Title and description
  - Direct link to view the report
  - Estimated execution time

#### Individual Report Pages

**Simple Reports (`/reports/simple`)**
- Basic tabular data display
- Customer information with clean formatting
- Real-time data updates
- Export options (when available)

**Complex Reports** (Future implementation)
- Multi-level grouping and aggregations
- Interactive filtering controls
- Chart and graph visualizations
- Drill-down capabilities

### Web Interface Controls

#### Data Management
- **Regenerate Sample Data**: Creates fresh demo data
- **Volume Control**: Select data size (small/medium/large)
- **Data Summary**: View current data statistics

#### Report Viewing
- **Format Selection**: Choose HTML, PDF, or JSON output
- **Parameter Input**: Set report filters and date ranges
- **Real-time Updates**: Automatic refresh when data changes
- **Export Options**: Download reports in various formats

#### Interactive Features
- **Live Filtering**: Filter data in real-time
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Progress Indicators**: Visual feedback during report generation

### Navigation Tips

1. **Start with Simple Reports**: Begin with `/reports/simple` to understand basic functionality
2. **Use Regenerate Data**: Click "Regenerate Sample Data" if reports appear empty
3. **Check Browser Console**: Look for JavaScript errors if reports don't load
4. **Refresh Page**: If data seems stale, refresh the browser page

## Understanding the Data Model

The demo uses a realistic business scenario with interconnected data:

### Core Entities

**Customers**
```elixir
%{
  id: 1,
  name: "John Doe",
  email: "john.doe@example.com",
  company: "Acme Corp",
  phone: "+1-555-0123",
  address: "123 Main St, City, State 12345",
  created_at: ~D[2024-01-15]
}
```

**Products**
```elixir
%{
  id: 1,
  name: "Professional Laptop",
  description: "High-performance laptop for business use",
  price: Decimal.new("1299.99"),
  category: "Electronics",
  sku: "LAPTOP-001",
  stock_quantity: 25
}
```

**Invoices**
```elixir
%{
  id: 1,
  invoice_number: "INV-2024-001",
  customer_id: 1,
  date: ~D[2024-03-15],
  due_date: ~D[2024-04-15],
  status: "paid",
  subtotal: Decimal.new("2599.98"),
  tax_rate: Decimal.new("0.08"),
  tax_amount: Decimal.new("207.99"),
  total: Decimal.new("2807.97")
}
```

### Relationships

- **One-to-Many**: Customer → Invoices
- **Many-to-Many**: Products ↔ Invoices (via InvoiceLineItems)
- **Calculated Fields**: Invoice totals, tax amounts, customer lifetime value
- **Referential Integrity**: All relationships maintained during data generation

### Data Volume Characteristics

| Volume | Customers | Products | Invoices | Line Items | Relationships |
|--------|-----------|----------|----------|------------|---------------|
| Small  | 10        | 50       | 25       | ~75        | Sparse        |
| Medium | 100       | 200      | 500      | ~1,500     | Realistic     |
| Large  | 1,000     | 2,000    | 10,000   | ~30,000    | Dense         |

## Report Types and Features

### 1. Customer Summary Report
**Purpose**: Analyze customer data and purchase patterns

**Features**:
- Customer contact information
- Total orders and revenue per customer
- Average order value calculations
- Customer status and activity metrics
- Sortable by various criteria

**Parameters**:
- `status`: Filter by customer status ("active", "inactive")
- `min_total_orders`: Minimum number of orders
- `date_range`: Specific time period

### 2. Product Inventory Report
**Purpose**: Track product stock and sales performance

**Features**:
- Current inventory levels
- Product pricing and categories
- Sales velocity calculations
- Low stock alerts
- Profit margin analysis

**Parameters**:
- `category`: Filter by product category
- `low_stock_threshold`: Alert threshold for inventory
- `include_inactive`: Show discontinued products

### 3. Invoice Details Report
**Purpose**: Comprehensive invoice analysis and tracking

**Features**:
- Detailed invoice information
- Payment status tracking
- Tax calculations and breakdowns
- Due date monitoring
- Revenue recognition

**Parameters**:
- `status`: Filter by payment status
- `start_date` / `end_date`: Date range filtering
- `customer_id`: Specific customer invoices
- `overdue_only`: Show only overdue invoices

### 4. Financial Summary Report
**Purpose**: High-level financial overview and KPI tracking

**Features**:
- Revenue totals and trends
- Tax collection summaries
- Outstanding receivables
- Period-over-period comparisons
- Key performance indicators

**Parameters**:
- `period`: "monthly", "quarterly", "yearly"
- `start_date` / `end_date`: Custom date range
- `include_projections`: Add forecast data
- `breakdown_by`: "customer", "product", "region"

### Advanced Report Features

**Hierarchical Band Structure**
- Page headers and footers
- Group headers with subtotals
- Detail bands with line-by-line data
- Summary bands with calculations

**Conditional Formatting**
- Color-coding based on values
- Icons for status indicators
- Font styling for emphasis
- Row highlighting for anomalies

**Calculations and Expressions**
- Field-level calculations
- Group-level aggregations
- Cross-tab summaries
- Custom formulas

## Performance and Benchmarking

### Performance Characteristics

**Data Generation Performance**:
- Small dataset: ~2-5 seconds
- Medium dataset: ~10-30 seconds
- Large dataset: ~60-180 seconds

**Report Execution Performance**:
- HTML reports: ~0.1-2 seconds
- JSON exports: ~0.1-1 seconds
- PDF generation: ~2-10 seconds (when enabled)

### Benchmarking Commands

```elixir
# Basic benchmark
AshReportsDemo.benchmark_reports()

# Comprehensive benchmark
AshReportsDemo.benchmark_reports(data_size: :large)

# Custom benchmark with timing
{time, _result} = :timer.tc(fn ->
  AshReportsDemo.run_report(:financial_summary, %{}, format: :html)
end)
IO.puts("Execution time: #{time / 1000} milliseconds")
```

### Memory Usage Monitoring

```elixir
# Before data generation
before = :erlang.memory(:total)

# Generate data
AshReportsDemo.generate_sample_data(:large)

# After data generation
after_gen = :erlang.memory(:total)
IO.puts("Memory used by data: #{(after_gen - before) / 1024 / 1024} MB")

# Monitor during report execution
:observer.start()  # GUI memory monitor
```

### Optimization Tips

1. **Use Appropriate Data Volumes**: Start with `:small` for development
2. **Monitor Memory**: Use `:observer.start()` to watch memory usage
3. **Clean Up Regularly**: Call `AshReportsDemo.reset_data()` between tests
4. **Format Selection**: HTML is fastest, PDF is slowest
5. **Parameter Filtering**: Use date ranges and filters to limit data scope

## Troubleshooting

### Common Issues and Solutions

#### 1. Application Won't Start

**Symptom**: Error messages during `iex -S mix` or `mix phx.server`

**Common Causes**:
- Missing dependencies
- Chrome/ChromeDriver not found (PDF functionality)
- Port conflicts

**Solutions**:
```bash
# Install dependencies
mix deps.get
mix deps.compile

# Start without PDF functionality
export DISABLE_PDF=true
iex -S mix

# Use different port
PORT=4001 mix phx.server
```

#### 2. Reports Show No Data

**Symptom**: Empty reports or "No data available" messages

**Solutions**:
```elixir
# Generate sample data first
AshReportsDemo.generate_sample_data(:medium)

# Check data summary
AshReportsDemo.data_summary()

# Validate data integrity
AshReportsDemo.DataGenerator.validate_data_integrity()
```

#### 3. PDF Generation Fails

**Symptom**: PDF reports return errors

**Solutions**:
```elixir
# Check PDF availability
AshReports.Application.chromic_pdf_available?()

# Use HTML format instead
AshReportsDemo.run_report(:customer_summary, %{}, format: :html)

# Disable PDF in configuration
# Add to config/dev.exs:
config :ash_reports, disable_pdf: true
```

#### 4. Performance Issues

**Symptom**: Slow report generation or memory issues

**Solutions**:
```elixir
# Use smaller datasets
AshReportsDemo.generate_sample_data(:small)

# Reset data between operations
AshReportsDemo.reset_data()

# Monitor memory usage
:observer.start()

# Use specific date ranges
AshReportsDemo.run_report(:financial_summary, %{
  start_date: ~D[2024-01-01],
  end_date: ~D[2024-01-31]
}, format: :html)
```

#### 5. Web Interface Issues

**Symptom**: Web pages don't load or show errors

**Solutions**:
```bash
# Restart Phoenix server
mix phx.server

# Check for port conflicts
lsof -i :4000

# Clear browser cache
# Use browser developer tools → Network → Clear cache

# Check JavaScript console for errors
# Use browser developer tools → Console
```

### Debug Mode

Enable detailed logging for troubleshooting:

```elixir
# Set debug level
Logger.configure(level: :debug)

# Enable detailed data generation logging
AshReportsDemo.DataGenerator.generate_sample_data(:small, debug: true)

# Trace report execution
AshReports.Runner.run_report(
  AshReportsDemo.Domain,
  :customer_summary,
  %{},
  format: :html,
  trace: true
)
```

### Getting Help

1. **Check Logs**: Look for error messages in IEx console
2. **Validate Environment**: Ensure all dependencies are installed
3. **Test with Small Data**: Use `:small` volume to isolate issues
4. **Reset State**: Call `AshReportsDemo.reset_data()` to clean state
5. **Restart Application**: Exit IEx and restart if problems persist

## FAQ

### General Questions

**Q: What is the purpose of this demo application?**
A: The demo showcases the comprehensive reporting capabilities of AshReports using a realistic business invoicing system. It demonstrates data generation, report execution, multiple output formats, and performance characteristics.

**Q: Do I need a database to run the demo?**
A: No! The demo uses ETS (Erlang Term Storage) as an in-memory data layer, requiring zero configuration while providing realistic relational data structures.

**Q: Can I use this demo code in production?**
A: The demo is designed for learning and evaluation. While the patterns shown are production-ready, you'll want to replace the ETS data layer with a proper database like PostgreSQL for production use.

### Technical Questions

**Q: Why do some PDF reports fail?**
A: PDF generation requires Chrome or Chromium to be installed on your system. If Chrome is not available, use HTML or JSON formats instead, or set `disable_pdf: true` in your configuration.

**Q: How realistic is the generated data?**
A: Very realistic! The demo uses the Faker library to generate authentic-looking names, addresses, companies, emails, and other business data with proper relationships and referential integrity.

**Q: Can I add custom reports?**
A: Yes! The demo is built on the full AshReports framework. You can define additional reports in the domain configuration and they'll automatically appear in both IEx and web interfaces.

**Q: What's the difference between data volumes?**
A:
- `:small` (25 records total): Quick testing and development
- `:medium` (800 records total): Realistic demo scenarios
- `:large` (13,000 records total): Performance testing and stress scenarios

**Q: How do I extend the data model?**
A: Add new resources to the `AshReportsDemo.Domain` and update the `DataGenerator` to create sample data for your new entities. The demo follows standard Ash Framework patterns.

### Performance Questions

**Q: Why is large dataset generation slow?**
A: Generating 13,000+ records with proper relationships and realistic data takes time. The process includes creating customers, products, invoices, line items, and validating all relationships. Use `:small` or `:medium` for faster development cycles.

**Q: How can I improve report performance?**
A:
- Use date range filters to limit data scope
- Select appropriate data volumes for your needs
- Choose HTML format for fastest rendering
- Reset data between tests to free memory

**Q: What are the memory requirements?**
A:
- `:small` dataset: ~10-20 MB
- `:medium` dataset: ~50-100 MB
- `:large` dataset: ~200-500 MB
- Add 50-100 MB for the Elixir runtime

### Development Questions

**Q: How do I contribute to the demo?**
A: The demo is part of the AshReports project. Follow the contribution guidelines in the main project repository.

**Q: Can I customize the report layouts?**
A: Absolutely! Reports are defined using the AshReports DSL. You can modify band structures, add calculations, change formatting, and customize the output appearance.

**Q: How do I run tests?**
A: Use standard Mix commands:
```bash
mix test                    # Run all tests
mix test --trace           # Verbose test output
mix test test/specific_test.exs  # Run specific test file
```

**Q: What's included in the web interface?**
A: The web interface provides:
- Report browsing and execution
- Data generation controls
- Real-time report viewing
- Responsive design for mobile/desktop
- Export functionality (where available)

### Best Practices

**Q: What's the recommended workflow for exploring the demo?**
A:
1. Start with `AshReportsDemo.start_demo()` for guided experience
2. Try different data volumes (`:small` → `:medium` → `:large`)
3. Explore all report types with various parameters
4. Use the web interface for visual report browsing
5. Run benchmarks to understand performance characteristics

**Q: How should I structure custom reports?**
A: Follow the existing patterns:
- Define clear band hierarchies (page → group → detail → summary)
- Use meaningful parameter names and validation
- Include appropriate calculations and aggregations
- Test with different data volumes
- Document expected parameters and outputs

---

This comprehensive user guide provides everything needed to effectively use and understand the AshReports Demo Application. For additional help or to report issues, please refer to the main AshReports project documentation and issue tracker.