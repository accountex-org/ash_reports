defmodule AshReports.Dsl.Band do
  @moduledoc """
  Represents a band in the AshReports hierarchical report structure.
  
  Bands are the building blocks of reports, representing different sections
  such as title, headers, detail rows, footers, and summary. Each band type
  has specific behavior and can contain columns and sub-bands.
  
  ## Band Types
  
  * `:title` - Report title band (appears once at the beginning)
  * `:page_header` - Appears at the top of each page
  * `:column_header` - Column headers for detail data
  * `:group_header` - Headers for grouped data (supports nesting)
  * `:detail` - The main data rows
  * `:group_footer` - Footers for grouped data (supports nesting)
  * `:column_footer` - Column footers with aggregations
  * `:page_footer` - Appears at the bottom of each page
  * `:summary` - Report summary band (appears once at the end)
  """
  
  defstruct [
    :name,
    :type,
    :columns,
    :bands,
    :height,
    :min_height,
    :max_height,
    :group_expression,
    :target_alias,
    :on_entry,
    :on_exit,
    :page_break,
    :column_break,
    :reprint_on_new_page,
    :visible,
    :style,
    :data_source,
    :reset_options,
    :variables,
    level: 0
  ]
  
  @type band_type :: :title | :page_header | :column_header | :group_header | 
                     :detail | :group_footer | :column_footer | :page_footer | :summary
  
  @type page_break_option :: :before | :after | :avoid | nil
  
  @type reset_option :: :page | :column | :group | :report | nil
  
  @type t :: %__MODULE__{
    name: atom() | nil,
    type: band_type(),
    columns: [AshReports.Dsl.Column.t()],
    bands: [t()],
    height: float() | nil,
    min_height: float() | nil,
    max_height: float() | nil,
    group_expression: Ash.Expr.t() | nil,
    target_alias: atom() | nil,
    on_entry: {module(), atom(), list()} | Ash.Expr.t() | nil,
    on_exit: {module(), atom(), list()} | Ash.Expr.t() | nil,
    page_break: page_break_option(),
    column_break: boolean(),
    reprint_on_new_page: boolean(),
    visible: boolean() | Ash.Expr.t(),
    style: map(),
    data_source: atom() | nil,
    reset_options: reset_option(),
    variables: map(),
    level: non_neg_integer()
  }
  
  @doc """
  Creates a new band struct with default values.
  """
  @spec new(band_type(), keyword()) :: t()
  def new(type, opts \\ []) when is_atom(type) do
    struct(
      __MODULE__,
      default_values_for_type(type)
      |> Keyword.merge(opts)
      |> Keyword.put(:type, type)
    )
  end
  
  @doc """
  Returns the default values for a specific band type.
  """
  @spec default_values_for_type(band_type()) :: keyword()
  def default_values_for_type(type) do
    base_defaults = [
      columns: [],
      bands: [],
      visible: true,
      style: %{},
      variables: %{},
      level: 0,
      column_break: false,
      reprint_on_new_page: false
    ]
    
    type_specific_defaults = case type do
      :title -> [reprint_on_new_page: false, page_break: nil]
      :page_header -> [reprint_on_new_page: true]
      :column_header -> [reprint_on_new_page: true]
      :group_header -> [page_break: nil, reset_options: :group]
      :detail -> [page_break: nil]
      :group_footer -> [page_break: nil, reset_options: :group]
      :column_footer -> [reprint_on_new_page: false]
      :page_footer -> [reprint_on_new_page: true]
      :summary -> [page_break: :before]
    end
    
    Keyword.merge(base_defaults, type_specific_defaults)
  end
  
  @doc """
  Validates a band struct.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{} = band) do
    with :ok <- validate_type(band),
         :ok <- validate_columns(band),
         :ok <- validate_sub_bands(band),
         :ok <- validate_group_settings(band),
         :ok <- validate_detail_settings(band) do
      {:ok, band}
    end
  end
  
  defp validate_type(%{type: type}) do
    if type in band_types() do
      :ok
    else
      {:error, "Invalid band type"}
    end
  end
  
  defp validate_columns(%{columns: columns}) when is_list(columns), do: :ok
  defp validate_columns(_), do: {:error, "Columns must be a list"}
  
  defp validate_sub_bands(%{bands: bands}) when is_list(bands), do: :ok
  defp validate_sub_bands(_), do: {:error, "Sub-bands must be a list"}
  
  defp validate_group_settings(%{type: type} = band) when type in [:group_header, :group_footer] do
    case band.group_expression do
      nil -> {:error, "Group bands require a group_expression"}
      _ -> :ok
    end
  end
  defp validate_group_settings(_), do: :ok
  
  defp validate_detail_settings(%{type: :detail, target_alias: nil}), do: :ok
  defp validate_detail_settings(%{type: :detail, target_alias: alias}) when is_atom(alias), do: :ok
  defp validate_detail_settings(%{type: :detail}), do: {:error, "Detail band target_alias must be an atom"}
  defp validate_detail_settings(_), do: :ok
  
  @doc """
  Returns all valid band types.
  """
  @spec band_types() :: [band_type()]
  def band_types do
    [:title, :page_header, :column_header, :group_header, :detail, 
     :group_footer, :column_footer, :page_footer, :summary]
  end
  
  @doc """
  Checks if a band type supports sub-bands.
  """
  @spec supports_sub_bands?(band_type()) :: boolean()
  def supports_sub_bands?(type) when type in [:group_header, :group_footer, :detail], do: true
  def supports_sub_bands?(_), do: false
  
  @doc """
  Checks if a band type supports grouping.
  """
  @spec supports_grouping?(band_type()) :: boolean()
  def supports_grouping?(type) when type in [:group_header, :group_footer], do: true
  def supports_grouping?(_), do: false
  
  @doc """
  Returns the maximum nesting level for group bands.
  """
  @spec max_group_level() :: pos_integer()
  def max_group_level, do: 74
  
  @doc """
  Adds a column to the band.
  """
  @spec add_column(t(), AshReports.Dsl.Column.t()) :: t()
  def add_column(%__MODULE__{columns: columns} = band, column) do
    %{band | columns: columns ++ [column]}
  end
  
  @doc """
  Adds a sub-band to the band.
  """
  @spec add_sub_band(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def add_sub_band(%__MODULE__{type: type} = parent, %__MODULE__{} = child) do
    if supports_sub_bands?(type) do
      # Set the child's level based on parent
      child = %{child | level: parent.level + 1}
      
      # Validate group nesting level
      if child.type in [:group_header, :group_footer] && child.level > max_group_level() do
        {:error, "Maximum group nesting level (#{max_group_level()}) exceeded"}
      else
        {:ok, %{parent | bands: parent.bands ++ [child]}}
      end
    else
      {:error, "Band type #{type} does not support sub-bands"}
    end
  end
  
  @doc """
  Gets all columns from the band and its sub-bands recursively.
  """
  @spec get_all_columns(t()) :: [AshReports.Dsl.Column.t()]
  def get_all_columns(%__MODULE__{columns: columns, bands: bands}) do
    sub_columns = Enum.flat_map(bands, &get_all_columns/1)
    columns ++ sub_columns
  end
  
  @doc """
  Finds a band by name within the band hierarchy.
  """
  @spec find_band_by_name(t(), atom()) :: t() | nil
  def find_band_by_name(%__MODULE__{name: name} = band, search_name) when name == search_name, do: band
  def find_band_by_name(%__MODULE__{bands: bands}, search_name) do
    Enum.find_value(bands, fn band -> find_band_by_name(band, search_name) end)
  end
  
  @doc """
  Calculates the total height of the band including sub-bands.
  """
  @spec calculate_total_height(t()) :: float()
  def calculate_total_height(%__MODULE__{height: nil, bands: bands}) do
    # If no explicit height, sum sub-band heights
    Enum.reduce(bands, 0.0, fn band, acc -> acc + calculate_total_height(band) end)
  end
  def calculate_total_height(%__MODULE__{height: height}) when is_number(height), do: height
  def calculate_total_height(_), do: 0.0
end