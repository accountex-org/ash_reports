defmodule AshReports.Resource do
  @moduledoc """
  Extension for making an Ash resource reportable.
  
  This extension allows you to configure how a resource appears in reports,
  including which reports can use it, default columns, and formatting options.
  
  ## Example
  
      defmodule MyApp.Product do
        use Ash.Resource,
          domain: MyApp.Store,
          extensions: [AshReports.Resource]
          
        reportable do
          reports [:inventory_summary, :sales_report]
          
          default_columns [:name, :category, :price, :stock_level]
          exclude_columns [:internal_notes, :cost]
          
          column_labels %{
            stock_level: "In Stock",
            unit_price: "Price (USD)"
          }
          
          column_formats %{
            price: :currency,
            stock_level: :number,
            created_at: :datetime
          }
        end
      end
  """
  
  use Spark.Dsl.Extension,
    sections: [AshReports.Dsl.reportable_section()]
  
  @doc """
  Get the list of reports this resource can be used with.
  """
  @spec list_reports(Ash.Resource.t()) :: list(atom())
  def list_reports(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:reportable], :reports, [])
  end
  
  @doc """
  Check if a resource can be used with a specific report.
  """
  @spec can_use_with_report?(Ash.Resource.t(), atom()) :: boolean()
  def can_use_with_report?(resource, report_name) do
    report_name in list_reports(resource)
  end
  
  @doc """
  Get the default columns for this resource when used in reports.
  """
  @spec default_columns(Ash.Resource.t()) :: list(atom()) | nil
  def default_columns(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:reportable], :default_columns, nil)
  end
  
  @doc """
  Get custom column labels for this resource.
  """
  @spec column_labels(Ash.Resource.t()) :: map()
  def column_labels(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:reportable], :column_labels, %{})
  end
  
  @doc """
  Get the label for a specific column.
  """
  @spec column_label(Ash.Resource.t(), atom()) :: String.t() | nil
  def column_label(resource, column_name) do
    labels = column_labels(resource)
    Map.get(labels, column_name)
  end
  
  @doc """
  Get default column formats for this resource.
  """
  @spec column_formats(Ash.Resource.t()) :: map()
  def column_formats(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:reportable], :column_formats, %{})
  end
  
  @doc """
  Get the format for a specific column.
  """
  @spec column_format(Ash.Resource.t(), atom()) :: atom() | nil
  def column_format(resource, column_name) do
    formats = column_formats(resource)
    Map.get(formats, column_name)
  end
  
  @doc """
  Get the list of columns to exclude from reports.
  """
  @spec exclude_columns(Ash.Resource.t()) :: list(atom())
  def exclude_columns(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:reportable], :exclude_columns, [])
  end
  
  @doc """
  Check if a column should be excluded from reports.
  """
  @spec exclude_column?(Ash.Resource.t(), atom()) :: boolean()
  def exclude_column?(resource, column_name) do
    column_name in exclude_columns(resource)
  end
  
  @doc """
  Get all reportable columns for a resource (attributes minus excluded).
  """
  @spec reportable_columns(Ash.Resource.t()) :: list(atom())
  def reportable_columns(resource) do
    excluded = exclude_columns(resource)
    
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.map(& &1.name)
    |> Enum.reject(&(&1 in excluded))
  end
end