defmodule AshReports do
  @moduledoc """
  AshReports - Comprehensive reporting extension for Ash Framework.
  
  AshReports provides a Spark DSL extension that adds reporting capabilities
  to Ash domains and resources. It supports hierarchical band-based report
  structures with multiple output formats including HTML, PDF, and HEEX.
  
  ## Features
  
  * Declarative report definition using Spark DSL
  * Hierarchical band structure (title, headers, details, footers, etc.)
  * Multiple output formats (HTML, PDF, HEEX)
  * Integration with Ash queries and resources
  * Compile-time report generation for optimal performance
  * Support for complex nested reports with grouping
  
  ## Usage
  
  Add reporting capabilities to your Ash domain:
  
      defmodule MyApp.Sales do
        use Ash.Domain,
          extensions: [AshReports.Domain]
        
        reports do
          report :monthly_sales do
            title "Monthly Sales Report"
            
            band :title do
              column :report_title, value: "Monthly Sales Summary"
            end
            
            band :detail do
              column :product_name, field: :name
              column :quantity_sold, field: :quantity
              column :total_revenue, field: :revenue, format: :currency
            end
          end
        end
      end
  
  Make resources reportable:
  
      defmodule MyApp.Sales.Order do
        use Ash.Resource,
          domain: MyApp.Sales,
          extensions: [AshReports.Resource]
        
        reportable do
          include_in_reports [:monthly_sales, :daily_summary]
        end
      end
  
  Generate reports:
  
      MyApp.Sales.Reports.MonthlyReport.generate(format: :pdf)
  """
  
  @doc """
  Returns the version of AshReports.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ash_reports, :vsn) |> to_string()
  end
  
  @doc """
  Lists all available report formats.
  """
  @spec available_formats() :: [:html | :pdf | :heex]
  def available_formats do
    [:html, :pdf, :heex]
  end
  
  @doc """
  Returns the default configuration for AshReports.
  """
  @spec default_config() :: keyword()
  def default_config do
    [
      default_formats: [:html, :pdf],
      report_storage_path: "priv/reports",
      cache_ttl: :timer.minutes(15),
      worker_pool_size: 5,
      max_concurrent_reports: 10
    ]
  end
end