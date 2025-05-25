defmodule AshReports.Dsl.Report do
  @moduledoc """
  Represents a report definition in the AshReports DSL.
  
  A report is the top-level entity that contains bands, configuration,
  and metadata for generating reports in various formats.
  """
  
  defstruct [
    :name,
    :title,
    :description,
    :resource,
    :domain,
    :formats,
    :parameters,
    :bands,
    :query_options,
    :page_size,
    :orientation,
    :margins,
    :styles,
    :data_sources,
    :variables,
    :on_before_report,
    :on_after_report,
    generated?: false
  ]
  
  @type band_type :: :title | :page_header | :column_header | :group_header | 
                     :detail | :group_footer | :column_footer | :page_footer | :summary
  
  @type format :: :html | :pdf | :heex
  
  @type orientation :: :portrait | :landscape
  
  @type page_size :: :a4 | :letter | :legal | :a3 | :custom
  
  @type margins :: %{
    top: float(),
    bottom: float(),
    left: float(),
    right: float()
  }
  
  @type parameter :: %{
    name: atom(),
    type: atom(),
    required?: boolean(),
    default: any(),
    description: String.t()
  }
  
  @type t :: %__MODULE__{
    name: atom(),
    title: String.t(),
    description: String.t() | nil,
    resource: module() | nil,
    domain: module(),
    formats: [format()],
    parameters: [parameter()],
    bands: [AshReports.Dsl.Band.t()],
    query_options: keyword(),
    page_size: page_size(),
    orientation: orientation(),
    margins: margins(),
    styles: map(),
    data_sources: map(),
    variables: map(),
    on_before_report: {module(), atom(), list()} | nil,
    on_after_report: {module(), atom(), list()} | nil,
    generated?: boolean()
  }
  
  @doc """
  Creates a new report struct with default values.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(
      __MODULE__,
      Keyword.merge(default_values(), opts)
    )
  end
  
  @doc """
  Returns the default values for a report.
  """
  @spec default_values() :: keyword()
  def default_values do
    [
      formats: [:html],
      parameters: [],
      bands: [],
      query_options: [],
      page_size: :a4,
      orientation: :portrait,
      margins: %{top: 0.5, bottom: 0.5, left: 0.5, right: 0.5},
      styles: %{},
      data_sources: %{},
      variables: %{},
      generated?: false
    ]
  end
  
  @doc """
  Validates a report struct.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{} = report) do
    with :ok <- validate_name(report),
         :ok <- validate_title(report),
         :ok <- validate_formats(report),
         :ok <- validate_bands(report),
         :ok <- validate_page_size(report),
         :ok <- validate_orientation(report) do
      {:ok, report}
    end
  end
  
  defp validate_name(%{name: nil}), do: {:error, "Report name is required"}
  defp validate_name(%{name: name}) when is_atom(name), do: :ok
  defp validate_name(_), do: {:error, "Report name must be an atom"}
  
  defp validate_title(%{title: nil}), do: {:error, "Report title is required"}
  defp validate_title(%{title: title}) when is_binary(title), do: :ok
  defp validate_title(_), do: {:error, "Report title must be a string"}
  
  defp validate_formats(%{formats: []}), do: {:error, "At least one format is required"}
  defp validate_formats(%{formats: formats}) do
    valid_formats = [:html, :pdf, :heex]
    invalid = Enum.reject(formats, &(&1 in valid_formats))
    
    if Enum.empty?(invalid) do
      :ok
    else
      {:error, "Invalid formats: #{inspect(invalid)}. Valid formats are: #{inspect(valid_formats)}"}
    end
  end
  
  defp validate_bands(%{bands: bands}) when is_list(bands), do: :ok
  defp validate_bands(_), do: {:error, "Bands must be a list"}
  
  defp validate_page_size(%{page_size: size}) when size in [:a4, :letter, :legal, :a3, :custom], do: :ok
  defp validate_page_size(_), do: {:error, "Invalid page size"}
  
  defp validate_orientation(%{orientation: o}) when o in [:portrait, :landscape], do: :ok
  defp validate_orientation(_), do: {:error, "Orientation must be :portrait or :landscape"}
  
  @doc """
  Returns all band types in hierarchical order.
  """
  @spec band_types() :: [band_type()]
  def band_types do
    [:title, :page_header, :column_header, :group_header, :detail, 
     :group_footer, :column_footer, :page_footer, :summary]
  end
  
  @doc """
  Checks if a band type appears only once in the report.
  """
  @spec single_occurrence_band?(band_type()) :: boolean()
  def single_occurrence_band?(band_type) when band_type in [:title, :summary], do: true
  def single_occurrence_band?(_), do: false
  
  @doc """
  Gets all bands of a specific type from the report.
  """
  @spec get_bands_by_type(t(), band_type()) :: [AshReports.Dsl.Band.t()]
  def get_bands_by_type(%__MODULE__{bands: bands}, type) do
    Enum.filter(bands, fn band -> band.type == type end)
  end
  
  @doc """
  Adds a band to the report.
  """
  @spec add_band(t(), AshReports.Dsl.Band.t()) :: {:ok, t()} | {:error, String.t()}
  def add_band(%__MODULE__{} = report, %AshReports.Dsl.Band{} = band) do
    if single_occurrence_band?(band.type) && has_band_type?(report, band.type) do
      {:error, "Report already has a #{band.type} band"}
    else
      {:ok, %{report | bands: report.bands ++ [band]}}
    end
  end
  
  defp has_band_type?(%__MODULE__{bands: bands}, type) do
    Enum.any?(bands, fn band -> band.type == type end)
  end
end