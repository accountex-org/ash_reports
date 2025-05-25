defmodule AshReports.Domain do
  @moduledoc """
  Extension for adding reporting capabilities to an Ash domain.
  
  This extension allows you to define reports at the domain level that can
  generate formatted output from resources within the domain.
  
  ## Example
  
      defmodule MyApp.Store do
        use Ash.Domain,
          extensions: [AshReports.Domain]
          
        reports do
          default_formats [:html, :pdf]
          default_locale "en-US"
          
          report :inventory_summary do
            title "Inventory Summary Report"
            description "Current inventory levels by category"
            
            band :title do
              column :title do
                value "Inventory Summary"
                align :center
              end
            end
            
            band :detail do
              column :product_name, field: :name
              column :quantity, field: :stock_level, format: :number
              column :value, value: fn record, _context -> 
                record.stock_level * record.unit_price 
              end, format: :currency
            end
          end
        end
      end
  """
  
  use Spark.Dsl.Extension,
    sections: [AshReports.Dsl.reports_section()],
    verifiers: [
      AshReports.Domain.Verifiers.ValidateReports
    ]
  
  @doc """
  Get all reports defined on a domain.
  """
  @spec list_reports(Ash.Domain.t()) :: list(AshReports.Dsl.Report.t())
  def list_reports(domain) do
    Spark.Dsl.Extension.get_entities(domain, [:reports])
  end
  
  @doc """
  Get a specific report by name.
  """
  @spec get_report(Ash.Domain.t(), atom()) :: AshReports.Dsl.Report.t() | nil
  def get_report(domain, name) do
    domain
    |> list_reports()
    |> Enum.find(&(&1.name == name))
  end
  
  @doc """
  Get the default page size for reports in this domain.
  """
  @spec default_page_size(Ash.Domain.t()) :: atom()
  def default_page_size(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:reports], :default_page_size, :a4)
  end
  
  @doc """
  Get the default orientation for reports in this domain.
  """
  @spec default_orientation(Ash.Domain.t()) :: atom()
  def default_orientation(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:reports], :default_orientation, :portrait)
  end
  
  @doc """
  Get the default renderer for reports in this domain.
  """
  @spec default_renderer(Ash.Domain.t()) :: atom() | nil
  def default_renderer(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:reports], :default_renderer, nil)
  end
  
  @doc """
  Get the default locale for reports in this domain.
  """
  @spec default_locale(Ash.Domain.t()) :: String.t()
  def default_locale(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:reports], :default_locale, "en")
  end
  
  @doc """
  Get the default time zone for reports in this domain.
  """
  @spec default_time_zone(Ash.Domain.t()) :: String.t()
  def default_time_zone(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:reports], :default_time_zone, "UTC")
  end
end