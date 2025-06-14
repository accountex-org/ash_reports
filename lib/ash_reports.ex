defmodule AshReports do
  @moduledoc """
  AshReports is a comprehensive reporting extension for the Ash Framework.
  
  It provides a declarative way to define complex reports with hierarchical band structures,
  supports multiple output formats (PDF, HTML, HEEX), includes internationalization via CLDR,
  and exposes reports through both an internal API server and an MCP server for LLM integration.
  
  ## Usage
  
  To use AshReports, add it as an extension to your Ash domain:
  
      defmodule MyApp.MyDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain]
        
        reports do
          report :sales_report do
            title "Sales Report"
            description "Monthly sales summary"
            driving_resource MyApp.Sales
            
            bands do
              band :title do
                type :title
                elements do
                  label :title_label do
                    text "Monthly Sales Report"
                    position x: 0, y: 0, width: 100, height: 20
                  end
                end
              end
            end
          end
        end
      end
  """

  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: @transformers,
    verifiers: @verifiers

  alias AshReports.Dsl

  @sections [
    Dsl.reports_section()
  ]

  @transformers [
    AshReports.Transformers.BuildReportModules
  ]

  @verifiers [
    AshReports.Verifiers.ValidateReports,
    AshReports.Verifiers.ValidateBands,
    AshReports.Verifiers.ValidateElements
  ]

  @doc """
  Get all reports defined in a domain.
  """
  @spec reports(Ash.Domain.t() | Spark.Dsl.t()) :: [AshReports.Report.t()]
  def reports(domain_or_dsl_state) do
    AshReports.Info.reports(domain_or_dsl_state)
  end

  @doc """
  Get a specific report by name.
  """
  @spec report(Ash.Domain.t() | Spark.Dsl.t(), atom()) :: AshReports.Report.t() | nil
  def report(domain_or_dsl_state, name) do
    AshReports.Info.report(domain_or_dsl_state, name)
  end

  @doc """
  List all available band types.
  """
  @spec band_types() :: [atom()]
  def band_types do
    [
      :title,
      :page_header,
      :column_header,
      :group_header,
      :detail_header,
      :detail,
      :detail_footer,
      :group_footer,
      :column_footer,
      :page_footer,
      :summary
    ]
  end

  @doc """
  List all available element types.
  """
  @spec element_types() :: [atom()]
  def element_types do
    [:field, :label, :expression, :aggregate, :line, :box, :image]
  end

  @doc """
  List all available variable types.
  """
  @spec variable_types() :: [atom()]
  def variable_types do
    [:sum, :count, :average, :min, :max, :custom]
  end

  @doc """
  List all available variable reset scopes.
  """
  @spec reset_scopes() :: [atom()]
  def reset_scopes do
    [:detail, :group, :page, :report]
  end

  @doc """
  List all supported output formats.
  """
  @spec format_types() :: [atom()]
  def format_types do
    [:html, :pdf, :heex, :json]
  end
end