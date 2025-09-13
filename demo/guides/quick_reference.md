# AshReports Demo - Quick Reference

Fast reference for common commands and operations.

## 🚀 Quick Start

```bash
cd demo
iex -S mix                              # Start console
# OR
mix phx.server                          # Start web interface (http://localhost:4000)
# OR
mix demo                                # Run interactive demo
```

## 📊 Essential IEx Commands

### Interactive Demo
```elixir
AshReportsDemo.start_demo()                    # Guided demo experience
AshReportsDemo.InteractiveDemo.quick_demo()   # Automated demo
```

### Data Management
```elixir
# Generate data
AshReportsDemo.generate_sample_data(:small)   # 10 customers, 50 products, 25 invoices
AshReportsDemo.generate_sample_data(:medium)  # 100 customers, 200 products, 500 invoices
AshReportsDemo.generate_sample_data(:large)   # 1000 customers, 2000 products, 10000 invoices

# Inspect data
AshReportsDemo.data_summary()                 # Get data counts
AshReportsDemo.list_reports()                 # List available reports

# Reset data
AshReportsDemo.reset_data()                   # Clear all data
```

### Run Reports
```elixir
# Basic reports
AshReportsDemo.run_report(:customer_summary, %{}, format: :html)
AshReportsDemo.run_report(:product_inventory, %{}, format: :html)
AshReportsDemo.run_report(:invoice_details, %{}, format: :html)
AshReportsDemo.run_report(:financial_summary, %{}, format: :html)

# With parameters
AshReportsDemo.run_report(:financial_summary, %{
  start_date: ~D[2024-01-01],
  end_date: ~D[2024-12-31]
}, format: :html)
```

### Performance Testing
```elixir
AshReportsDemo.benchmark_reports()                    # Default benchmark
AshReportsDemo.benchmark_reports(data_size: :large)   # Large dataset benchmark
```

## 🌐 Web Interface Quick Guide

### URLs
- **Homepage**: `http://localhost:4000/`
- **Reports Dashboard**: `http://localhost:4000/reports`
- **Simple Report**: `http://localhost:4000/reports/simple`

### Key Actions
1. **Generate Data**: Click "Regenerate Sample Data" button
2. **View Reports**: Click "View Report" on any report card
3. **Navigate**: Use browser back button or main navigation

## 🔧 Common Workflows

### First Time Setup
```elixir
# 1. Start IEx
iex -S mix

# 2. Run guided demo
AshReportsDemo.start_demo()

# 3. Follow prompts to generate data and run reports
```

### Development Testing
```elixir
# Generate test data
AshReportsDemo.generate_sample_data(:small)

# Test all reports
for report <- AshReportsDemo.list_reports() do
  case AshReportsDemo.run_report(report, %{}, format: :html) do
    {:ok, _} -> IO.puts("✅ #{report}")
    {:error, reason} -> IO.puts("❌ #{report}: #{reason}")
  end
end

# Clean up
AshReportsDemo.reset_data()
```

### Performance Analysis
```elixir
# Time a specific operation
{time, _result} = :timer.tc(fn ->
  AshReportsDemo.generate_sample_data(:medium)
end)
IO.puts("Data generation: #{time / 1000}ms")

# Memory usage
before = :erlang.memory(:total)
AshReportsDemo.generate_sample_data(:large)
after_data = :erlang.memory(:total)
IO.puts("Memory used: #{(after_data - before) / 1024 / 1024}MB")
```

## 🏗️ Data Volumes Reference

| Volume | Customers | Products | Invoices | Generation Time | Memory Usage |
|--------|-----------|----------|----------|-----------------|--------------|
| :small | 10        | 50       | 25       | ~2-5 sec        | ~10-20 MB    |
| :medium| 100       | 200      | 500      | ~10-30 sec      | ~50-100 MB   |
| :large | 1,000     | 2,000    | 10,000   | ~60-180 sec     | ~200-500 MB  |

## 📋 Available Reports

1. **`:customer_summary`** - Customer data and purchase patterns
2. **`:product_inventory`** - Product stock and sales performance
3. **`:invoice_details`** - Comprehensive invoice analysis
4. **`:financial_summary`** - Financial overview and KPIs

## 🚨 Troubleshooting Quick Fixes

### Application Won't Start
```bash
mix deps.get                    # Install dependencies
export DISABLE_PDF=true        # Disable PDF if Chrome missing
iex -S mix                      # Restart
```

### Reports Show No Data
```elixir
AshReportsDemo.generate_sample_data(:medium)   # Generate data
AshReportsDemo.data_summary()                  # Verify data exists
```

### Performance Issues
```elixir
AshReportsDemo.reset_data()                    # Clear memory
AshReportsDemo.generate_sample_data(:small)   # Use smaller dataset
:observer.start()                              # Monitor memory
```

### Web Interface Issues
```bash
# Restart Phoenix server
mix phx.server

# Try different port
PORT=4001 mix phx.server

# Clear browser cache and reload page
```

## 🎯 Common Parameters

### Report Parameters
```elixir
# Date filtering
%{start_date: ~D[2024-01-01], end_date: ~D[2024-12-31]}

# Status filtering
%{status: "active"}              # Customer status
%{status: "paid"}                # Invoice status

# Threshold filtering
%{min_total_orders: 100}         # Minimum order count
%{low_stock_threshold: 10}       # Inventory alerts
```

### Format Options
- `:html` - Web display (fastest)
- `:json` - Structured data export
- `:pdf` - Print-ready documents (requires Chrome)

## 💡 Pro Tips

1. **Start Small**: Use `:small` data volume for development and testing
2. **Monitor Memory**: Use `:observer.start()` to watch resource usage
3. **Reset Between Tests**: Call `reset_data()` to clear state
4. **Use Date Ranges**: Filter reports by date for better performance
5. **Check Data First**: Always verify data exists with `data_summary()`
6. **Bookmark Commands**: Save frequently used commands in a file

## 🔍 Debug Commands

```elixir
# System status
AshReports.Application.chromic_pdf_available?()        # Check PDF support
AshReportsDemo.DataGenerator.health_check()           # System health
:sys.get_state(AshReportsDemo.DataGenerator)          # GenServer state

# Data validation
AshReportsDemo.DataGenerator.validate_data_integrity() # Check relationships
AshReportsDemo.DataGenerator.get_statistics()         # Detailed stats

# Logging
Logger.configure(level: :debug)                       # Enable debug logs
```

---

Keep this reference handy for quick access to the most commonly used commands and workflows!