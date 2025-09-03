# Graphs and Visualizations

AshReports includes a powerful chart engine that automatically generates interactive visualizations from your report data. This guide covers chart creation, customization, and integration with different output formats.

## Table of Contents

- [Chart Engine Overview](#chart-engine-overview)
- [Chart Types](#chart-types)
- [Chart Providers](#chart-providers)
- [Chart Configuration](#chart-configuration)
- [Auto Chart Selection](#auto-chart-selection)
- [Interactive Features](#interactive-features)
- [Chart Integration in Reports](#chart-integration-in-reports)
- [Complete Examples](#complete-examples)

## Chart Engine Overview

The AshReports Chart Engine provides:

- **Multi-Provider Support**: Chart.js (default), D3.js, and Plotly
- **Automatic Chart Selection**: Intelligent chart type recommendations based on data
- **Output Format Integration**: SVG for PDF, interactive charts for HTML/HEEX
- **Internationalization**: Full RTL support and locale-aware formatting
- **Real-time Updates**: LiveView integration for dynamic data

### Basic Chart Generation

```elixir
# Basic chart configuration
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: sales_data,
  title: "Monthly Sales Trend",
  provider: :chartjs
}

# Generate chart
{:ok, chart} = AshReports.ChartEngine.generate(chart_config, render_context)
```

## Chart Types

AshReports supports a comprehensive set of chart types:

### Basic Charts

#### Line Charts
Perfect for time series data and trends:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: [
    {~D[2024-01], 1200},
    {~D[2024-02], 1500},
    {~D[2024-03], 1300},
    {~D[2024-04], 1800}
  ],
  title: "Monthly Revenue Trend",
  options: %{
    scales: %{
      x: %{title: %{display: true, text: "Month"}},
      y: %{title: %{display: true, text: "Revenue ($)"}}
    }
  }
}
```

#### Bar Charts
Ideal for categorical comparisons:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :bar,
  data: [
    {"North", 25000},
    {"South", 18000},
    {"East", 22000},
    {"West", 19000}
  ],
  title: "Sales by Region",
  options: %{
    indexAxis: "y",  # Horizontal bars
    responsive: true
  }
}
```

#### Pie Charts
Best for proportional data:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :pie,
  data: [
    {"Product A", 35},
    {"Product B", 25},
    {"Product C", 20},
    {"Product D", 20}
  ],
  title: "Market Share Distribution",
  options: %{
    plugins: %{
      legend: %{position: "right"}
    }
  }
}
```

#### Area Charts
Great for cumulative data:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :area,
  data: %{
    "Q1" => [100, 150, 200],
    "Q2" => [120, 180, 250],
    "Q3" => [140, 200, 300],
    "Q4" => [160, 220, 350]
  },
  title: "Quarterly Growth Stacked",
  options: %{
    scales: %{
      y: %{stacked: true}
    }
  }
}
```

### Advanced Charts

#### Scatter Plots
For correlation analysis:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :scatter,
  data: [
    {25, 120000},  # {age, salary}
    {30, 150000},
    {35, 180000},
    {40, 210000}
  ],
  title: "Age vs Salary Correlation",
  options: %{
    scales: %{
      x: %{title: %{display: true, text: "Age"}},
      y: %{title: %{display: true, text: "Salary ($)"}}
    }
  }
}
```

#### Histogram Charts
For frequency distribution:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :histogram,
  data: [20, 25, 30, 32, 35, 38, 40, 42, 45, 48, 50],
  title: "Age Distribution",
  options: %{
    bins: 5,
    scales: %{
      x: %{title: %{display: true, text: "Age Groups"}},
      y: %{title: %{display: true, text: "Frequency"}}
    }
  }
}
```

#### Box Plots
For statistical summaries:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :boxplot,
  data: %{
    "Dataset 1" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "Dataset 2" => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
  },
  title: "Performance Distribution",
  provider: :plotly  # Box plots work best with Plotly
}
```

#### Heatmaps
For density visualization:

```elixir
chart_config = %AshReports.ChartConfig{
  type: :heatmap,
  data: %{
    x_labels: ["Mon", "Tue", "Wed", "Thu", "Fri"],
    y_labels: ["9AM", "10AM", "11AM", "12PM", "1PM"],
    values: [
      [10, 20, 30, 40, 50],
      [15, 25, 35, 45, 55],
      [20, 30, 40, 50, 60],
      [25, 35, 45, 55, 65],
      [30, 40, 50, 60, 70]
    ]
  },
  title: "Activity Heatmap",
  provider: :d3
}
```

## Chart Providers

Each chart provider has different strengths and capabilities:

### Chart.js Provider (Default)
Best for: Standard business charts, responsive web applications

```elixir
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: sales_data,
  provider: :chartjs,
  options: %{
    responsive: true,
    maintainAspectRatio: false,
    interaction: %{
      intersect: false,
      mode: "index"
    },
    plugins: %{
      tooltip: %{
        enabled: true,
        backgroundColor: "rgba(0,0,0,0.8)"
      }
    }
  }
}
```

### D3.js Provider (Advanced)
Best for: Custom visualizations, complex interactions

```elixir
chart_config = %AshReports.ChartConfig{
  type: :custom,
  data: network_data,
  provider: :d3,
  options: %{
    visualization_type: "force_directed_graph",
    node_size: 10,
    link_distance: 100,
    charge: -300,
    animations: %{
      duration: 750,
      easing: "ease-in-out"
    }
  }
}
```

### Plotly Provider (Scientific)
Best for: Scientific charts, 3D visualizations

```elixir
chart_config = %AshReports.ChartConfig{
  type: :surface3d,
  data: scientific_data,
  provider: :plotly,
  options: %{
    scene: %{
      xaxis: %{title: "X Axis"},
      yaxis: %{title: "Y Axis"},
      zaxis: %{title: "Z Axis"}
    },
    colorscale: "Viridis"
  }
}
```

## Chart Configuration

### Basic Configuration Structure

```elixir
defstruct [
  :type,           # Chart type (:line, :bar, :pie, etc.)
  :data,           # Chart data (list, map, or structured data)
  :title,          # Chart title
  :provider,       # Chart provider (:chartjs, :d3, :plotly)
  :options,        # Provider-specific options
  :interactive,    # Enable interactivity (boolean)
  :real_time,      # Enable real-time updates (boolean)
  :update_interval, # Update frequency in milliseconds
  :confidence,     # Auto-selection confidence (0.0 - 1.0)
  :reasoning       # Auto-selection reasoning (string)
]
```

### Advanced Configuration

```elixir
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: time_series_data,
  title: "Advanced Sales Analysis",
  provider: :chartjs,
  interactive: true,
  real_time: false,
  
  options: %{
    # Responsiveness
    responsive: true,
    maintainAspectRatio: false,
    
    # Scales configuration
    scales: %{
      x: %{
        type: "time",
        time: %{
          unit: "month",
          displayFormats: %{
            month: "MMM YYYY"
          }
        },
        title: %{
          display: true,
          text: "Time Period"
        }
      },
      y: %{
        beginAtZero: true,
        title: %{
          display: true,
          text: "Sales Amount ($)"
        },
        ticks: %{
          callback: "function(value) { return '$' + value.toLocaleString(); }"
        }
      }
    },
    
    # Plugins
    plugins: %{
      legend: %{
        display: true,
        position: "top"
      },
      tooltip: %{
        enabled: true,
        mode: "index",
        intersect: false,
        callbacks: %{
          label: "function(context) { return context.dataset.label + ': $' + context.parsed.y.toLocaleString(); }"
        }
      }
    },
    
    # Interactions
    interaction: %{
      intersect: false,
      mode: "index"
    },
    
    # Animations
    animation: %{
      duration: 1000,
      easing: "easeInOutQuart"
    }
  }
}
```

## Auto Chart Selection

The Chart Engine can automatically suggest appropriate chart types based on your data:

### Automatic Analysis

```elixir
# Sample data for analysis
sales_data = %{
  revenue: [100000, 150000, 200000, 175000, 225000],
  months: ["Jan", "Feb", "Mar", "Apr", "May"],
  categories: ["Product A", "Product B", "Product C"],
  values: [35, 25, 40]
}

# Get automatic chart suggestions
suggestions = AshReports.ChartEngine.auto_select_charts(sales_data, context)

# Results in:
[
  %AshReports.ChartConfig{
    type: :line,
    confidence: 0.9,
    reasoning: "Time series data best shown as line chart",
    data: revenue_by_month
  },
  %AshReports.ChartConfig{
    type: :pie,
    confidence: 0.8,
    reasoning: "Small categorical dataset good for pie chart",
    data: category_breakdown
  },
  %AshReports.ChartConfig{
    type: :bar,
    confidence: 0.9,
    reasoning: "Bar chart excellent for categorical comparisons",
    data: category_values
  }
]
```

### Manual Selection Criteria

You can also implement custom selection logic:

```elixir
defp select_chart_type(data) do
  case analyze_data_characteristics(data) do
    %{type: :time_series, points: points} when points > 10 ->
      {:line, 0.9, "Line chart ideal for time series with many data points"}
    
    %{type: :categorical, categories: cats} when length(cats) <= 5 ->
      {:pie, 0.8, "Pie chart works well for small number of categories"}
    
    %{type: :categorical, categories: cats} when length(cats) > 5 ->
      {:bar, 0.9, "Bar chart better for many categories"}
    
    %{type: :correlation} ->
      {:scatter, 0.8, "Scatter plot shows correlation relationships"}
    
    %{type: :distribution} ->
      {:histogram, 0.7, "Histogram shows data distribution"}
    
    _ ->
      {:bar, 0.5, "Default bar chart for general data"}
  end
end
```

## Interactive Features

### Real-time Updates

```elixir
chart_config = %AshReports.ChartConfig{
  type: :line,
  data: initial_data,
  title: "Live Sales Dashboard",
  interactive: true,
  real_time: true,
  update_interval: 30_000,  # Update every 30 seconds
  
  options: %{
    animation: %{
      duration: 500
    },
    plugins: %{
      streaming: %{
        duration: 20000,  # Show last 20 seconds of data
        refresh: 1000,    # Refresh every second
        delay: 2000       # Delay for incoming data
      }
    }
  }
}
```

### Interactive Filtering

```elixir
chart_config = %AshReports.ChartConfig{
  type: :bar,
  data: filtered_data,
  title: "Interactive Sales Analysis",
  interactive: true,
  
  options: %{
    plugins: %{
      zoom: %{
        zoom: %{
          wheel: %{enabled: true},
          pinch: %{enabled: true},
          mode: "x"
        },
        pan: %{
          enabled: true,
          mode: "x"
        }
      },
      
      # Custom filter controls
      filters: %{
        date_range: %{
          enabled: true,
          default: %{start: "2024-01-01", end: "2024-12-31"}
        },
        category_filter: %{
          enabled: true,
          options: ["All", "Product A", "Product B", "Product C"]
        }
      }
    },
    
    # Event handlers for LiveView
    onClick: "handle_chart_click",
    onHover: "handle_chart_hover"
  }
}
```

## Chart Integration in Reports

### Chart Elements in Bands

Charts can be embedded directly in report bands as special elements:

```elixir
bands do
  band :sales_visualization do
    type :detail_header
    elements do
      # Chart element
      chart :sales_trend_chart do
        type :line
        data_source expr(
          # Group sales by month
          sales
          |> group_by([s], date_part(s.date, :month))
          |> select([s], {date_part(s.date, :month), sum(s.total)})
        )
        title "Monthly Sales Trend"
        position x: 0, y: 0, width: 100, height: 40
        
        options %{
          responsive: true,
          maintainAspectRatio: false
        }
      end
      
      # Chart with custom data processing
      chart :category_breakdown do
        type :pie
        data_source expr(
          # Group by product category
          line_items
          |> join(:inner, [li], p in assoc(li, :product))
          |> join(:inner, [li, p], pc in assoc(p, :category))
          |> group_by([li, p, pc], pc.name)
          |> select([li, p, pc], {pc.name, sum(li.line_total)})
        )
        title "Sales by Category"
        position x: 0, y: 45, width: 50, height: 30
        
        conditional expr(count(line_items) > 0)  # Only show if data exists
      end
    end
  end
end
```

### Chart Variables

Use variables to accumulate data for charts:

```elixir
variables do
  # Accumulate data points for trending
  variable :monthly_totals do
    type :custom
    expression expr(%{
      month: date_part(date, :month),
      total: total
    })
    reset_on :report
  end
  
  # Category accumulator
  variable :category_totals do
    type :custom  
    expression expr(%{
      category: product.category.name,
      amount: line_items.line_total
    })
    reset_on :group
  end
end

bands do
  band :trend_analysis do
    type :summary
    elements do
      # Use variable data in chart
      chart :trend_from_variable do
        type :line
        data_source variable(:monthly_totals)
        title "Accumulated Trend"
      end
    end
  end
end
```

### Multi-Chart Dashboards

Create comprehensive dashboards with multiple related charts:

```elixir
band :dashboard do
  type :summary
  elements do
    # Overview chart
    chart :revenue_overview do
      type :line
      data_source expr(monthly_revenue_data)
      title "Revenue Trend"
      position x: 0, y: 0, width: 50, height: 25
    end
    
    # Breakdown chart
    chart :revenue_breakdown do
      type :pie
      data_source expr(revenue_by_category)
      title "Revenue by Category"
      position x: 50, y: 0, width: 25, height: 25
    end
    
    # Performance indicators
    chart :performance_metrics do
      type :bar
      data_source expr(kpi_data)
      title "Key Metrics"
      position x: 75, y: 0, width: 25, height: 25
    end
    
    # Regional comparison
    chart :regional_comparison do
      type :bar
      data_source expr(regional_sales_data)
      title "Sales by Region"
      position x: 0, y: 30, width: 50, height: 20
      
      options %{
        indexAxis: "y"  # Horizontal bars
      }
    end
    
    # Trend correlation
    chart :correlation_analysis do
      type: :scatter
      data_source expr(correlation_data)
      title "Marketing vs Sales Correlation"
      position x: 50, y: 30, width: 50, height: 20
    end
  end
end
```

## Complete Examples

### Sales Dashboard Report with Multiple Charts

```elixir
report :sales_dashboard do
  title "Executive Sales Dashboard"
  description "Comprehensive sales analysis with interactive visualizations"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :year, :integer, default: Date.utc_today().year
    parameter :quarter, :integer
    parameter :region, :string
  end
  
  scope expr(
    date_part(date, :year) == ^year and
    if(not is_nil(^quarter), date_part(date, :quarter) == ^quarter, true) and
    if(not is_nil(^region), customer.region == ^region, true)
  )
  
  variables do
    variable :monthly_data do
      type :custom
      expression expr(%{
        month: date_part(date, :month),
        total: total,
        count: 1
      })
      reset_on :report
    end
    
    variable :category_data do
      type :custom
      expression expr(%{
        category: line_items.product.category.name,
        amount: line_items.line_total
      })
      reset_on :report
    end
  end
  
  bands do
    band :title do
      type :title
      elements do
        label :dashboard_title do
          text "Executive Sales Dashboard"
          style font_size: 24, font_weight: :bold, alignment: :center
        end
        
        expression :period_display do
          expression expr(
            "Year: " <> to_string(^year) <>
            if(not is_nil(^quarter), " Q" <> to_string(^quarter), "") <>
            if(not is_nil(^region), " - Region: " <> ^region, "")
          )
          style font_size: 14, alignment: :center
        end
      end
    end
    
    band :kpi_summary do
      type :page_header
      elements do
        # Key metrics as simple aggregates
        aggregate :total_revenue do
          function :sum
          source :total
          scope :report
          format :currency
          position x: 0, y: 0, width: 25, height: 15
        end
        
        aggregate :total_invoices do
          function :count
          source :id
          scope :report
          position x: 25, y: 0, width: 25, height: 15
        end
        
        aggregate :average_invoice do
          function :average
          source :total
          scope :report
          format :currency
          position x: 50, y: 0, width: 25, height: 15
        end
        
        expression :growth_rate do
          expression expr("12.5% Growth")  # Would be calculated from data
          style color: :green, font_weight: :bold
          position x: 75, y: 0, width: 25, height: 15
        end
      end
    end
    
    band :charts_section do
      type :detail
      elements do
        # Main revenue trend chart
        chart :revenue_trend do
          type :line
          data_source variable(:monthly_data)
          title "Monthly Revenue Trend"
          position x: 0, y: 0, width: 70, height: 30
          
          options %{
            responsive: true,
            scales: %{
              x: %{
                title: %{display: true, text: "Month"}
              },
              y: %{
                title: %{display: true, text: "Revenue ($)"},
                beginAtZero: true
              }
            },
            plugins: %{
              legend: %{display: false}
            }
          }
        end
        
        # Top customers chart
        chart :top_customers do
          type :bar
          data_source expr(
            # Top 5 customers by total revenue
            invoices
            |> group_by([i], i.customer_id)
            |> join(:inner, [i], c in assoc(i, :customer))
            |> select([i, c], {c.name, sum(i.total)})
            |> order_by([i, c], desc: sum(i.total))
            |> limit(5)
          )
          title "Top 5 Customers"
          position x: 70, y: 0, width: 30, height: 30
          
          options %{
            indexAxis: "y",
            plugins: %{
              legend: %{display: false}
            }
          }
        end
        
        # Category breakdown pie chart
        chart :category_breakdown do
          type :pie
          data_source variable(:category_data)
          title "Revenue by Category"
          position x: 0, y: 35, width: 35, height: 25
          
          options %{
            plugins: %{
              legend: %{
                position: "right"
              }
            }
          }
        end
        
        # Regional performance
        chart :regional_performance do
          type :bar
          data_source expr(
            invoices
            |> join(:inner, [i], c in assoc(i, :customer))
            |> group_by([i, c], c.region)
            |> select([i, c], {c.region, sum(i.total)})
          )
          title "Performance by Region"
          position x: 35, y: 35, width: 35, height: 25
          
          conditional expr(is_nil(^region))  # Only show if not filtering by region
        end
        
        # Monthly comparison (current vs previous year)
        chart :year_comparison do
          type :line
          data_source expr(
            # This would require more complex query to compare years
            monthly_comparison_data
          )
          title "Year-over-Year Comparison"
          position x: 70, y: 35, width: 30, height: 25
          
          options %{
            scales: %{
              x: %{title: %{display: true, text: "Month"}},
              y: %{title: %{display: true, text: "Revenue ($)"}}
            },
            plugins: %{
              legend: %{
                display: true,
                position: "top"
              }
            }
          }
        end
      end
    end
    
    band :detailed_analysis do
      type :detail_footer
      elements do
        # Sales funnel chart
        chart :sales_funnel do
          type :bar
          data_source expr(
            [
              {"Prospects", 1000},
              {"Qualified", 300},
              {"Proposals", 100},
              {"Closed", 25}
            ]
          )
          title "Sales Funnel Analysis"
          position x: 0, y: 0, width: 50, height: 20
          
          options %{
            backgroundColor: ["#e3f2fd", "#bbdefb", "#90caf9", "#42a5f5"]
          }
        end
        
        # Performance heatmap
        chart :performance_heatmap do
          type :heatmap
          provider :d3
          data_source expr(performance_matrix_data)
          title "Sales Rep Performance Matrix"
          position x: 50, y: 0, width: 50, height: 20
          
          options %{
            colorScale: "RdYlGn"
          }
        end
      end
    end
    
    band :footer do
      type :page_footer
      elements do
        expression :generated_info do
          expression expr(
            "Generated on " <> to_string(DateTime.utc_now()) <>
            " | Page " <> to_string(page_number)
          )
          style font_size: 10, alignment: :right
        end
      end
    end
  end
end
```

### Interactive LiveView Integration

```elixir
# In your LiveView module
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Set up real-time updates
      :timer.send_interval(30_000, self(), :update_charts)
    end
    
    socket = 
      socket
      |> assign(:report_params, %{year: Date.utc_today().year})
      |> load_dashboard_data()
    
    {:ok, socket}
  end
  
  def handle_info(:update_charts, socket) do
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end
  
  def handle_event("filter_change", %{"year" => year}, socket) do
    params = %{socket.assigns.report_params | year: String.to_integer(year)}
    
    socket =
      socket
      |> assign(:report_params, params)
      |> load_dashboard_data()
    
    {:noreply, socket}
  end
  
  def handle_event("chart_click", %{"chart" => chart_id, "data" => data}, socket) do
    # Handle chart interactions
    case chart_id do
      "revenue_trend" ->
        # Drill down to specific month
        handle_month_drilldown(socket, data)
      
      "category_breakdown" ->
        # Filter by category
        handle_category_filter(socket, data)
      
      _ ->
        {:noreply, socket}
    end
  end
  
  defp load_dashboard_data(socket) do
    {:ok, report_html} = AshReports.generate(
      MyApp.MyDomain,
      :sales_dashboard,
      socket.assigns.report_params,
      :heex
    )
    
    assign(socket, :dashboard_content, report_html)
  end
end
```

### Chart-Focused Financial Report

```elixir
report :financial_charts_report do
  title "Financial Performance Analysis"
  driving_resource MyApp.Invoice
  
  parameters do
    parameter :start_date, :date, required: true
    parameter :end_date, :date, required: true
    parameter :comparison_period, :boolean, default: false
  end
  
  bands do
    band :executive_summary_charts do
      type :title
      elements do
        # Revenue waterfall chart
        chart :revenue_waterfall do
          type :bar  # Waterfall style with custom coloring
          data_source expr(waterfall_data)
          title "Revenue Waterfall Analysis"
          position x: 0, y: 0, width: 100, height: 25
          
          options %{
            scales: %{
              y: %{beginAtZero: true}
            },
            plugins: %{
              legend: %{display: false}
            },
            backgroundColor: [
              "#4CAF50",  # Positive - green
              "#F44336",  # Negative - red  
              "#2196F3"   # Neutral - blue
            ]
          }
        end
        
        # Profitability trend
        chart :profitability_trend do
          type :line
          data_source expr(profit_margin_data)
          title "Profitability Trend (%)"
          position x: 0, y: 30, width: 50, height: 20
          
          options %{
            scales: %{
              y: %{
                title: %{display: true, text: "Profit Margin %"},
                ticks: %{
                  callback: "function(value) { return value + '%'; }"
                }
              }
            },
            elements: %{
              line: %{tension: 0.4}  # Smooth curve
            }
          }
        end
        
        # Cash flow analysis
        chart :cash_flow do
          type :area
          data_source expr(cash_flow_data)
          title "Cash Flow Analysis"
          position x: 50, y: 30, width: 50, height: 20
          
          options %{
            scales: %{
              y: %{
                stacked: true,
                title: %{display: true, text: "Cash Flow ($)"}
              }
            },
            elements: %{
              area: %{
                backgroundColor: "rgba(75,192,192,0.2)",
                borderColor: "rgba(75,192,192,1)"
              }
            }
          }
        end
      end
    end
    
    band :detailed_financial_charts do
      type :detail
      elements do
        # Accounts receivable aging
        chart :ar_aging do
          type :bar
          data_source expr(ar_aging_data)
          title "Accounts Receivable Aging"
          position x: 0, y: 0, width: 33, height: 25
          
          options %{
            backgroundColor: [
              "#4CAF50",  # Current
              "#FFC107",  # 30 days
              "#FF9800",  # 60 days
              "#F44336"   # 90+ days
            ]
          }
        end
        
        # Customer concentration risk
        chart :customer_concentration do
          type :pie
          data_source expr(top_customer_revenue_percentage)
          title "Customer Concentration Risk"
          position x: 33, y: 0, width: 34, height: 25
          
          options %{
            plugins: %{
              datalabels: %{
                formatter: "function(value, ctx) { return value + '%'; }"
              }
            }
          }
        end
        
        # Monthly recurring revenue
        chart :mrr_trend do
          type :line
          data_source expr(mrr_data)
          title "Monthly Recurring Revenue Growth"
          position x: 67, y: 0, width: 33, height: 25
          
          options %{
            scales: %{
              y: %{
                title: %{display: true, text: "MRR ($)"}
              }
            },
            plugins: %{
              annotation: %{
                annotations: %{
                  target_line: %{
                    type: "line",
                    yMin: 100000,
                    yMax: 100000,
                    borderColor: "rgb(255, 99, 132)",
                    borderWidth: 2,
                    label: %{
                      content: "Target",
                      enabled: true
                    }
                  }
                }
              }
            }
          }
        end
      end
    end
  end
end
```

This comprehensive guide demonstrates how to leverage AshReports' chart engine to create rich, interactive visualizations that enhance your reports with compelling data presentations. The chart system integrates seamlessly with the report DSL and supports multiple output formats for maximum flexibility.