defmodule AshReports.Dsl.Column do
  @moduledoc """
  Represents a column definition in a report band.
  
  Columns define how data is displayed within bands, including field mapping,
  formatting, alignment, and calculated values.
  """
  
  defstruct [
    :name,
    :label,
    :field,
    :value,
    :format,
    :format_options,
    :width,
    :min_width,
    :max_width,
    :alignment,
    :vertical_alignment,
    :aggregate,
    :aggregate_options,
    :visible,
    :style,
    :header_style,
    :footer_style,
    :on_render,
    :sortable,
    :sort_field,
    :word_wrap,
    :truncate
  ]
  
  @type alignment :: :left | :center | :right | :justify
  @type vertical_alignment :: :top | :middle | :bottom
  @type format_type :: :text | :number | :currency | :percentage | :date | :datetime | :boolean | :custom
  @type aggregate_type :: :count | :sum | :avg | :min | :max | :first | :last | :list
  
  @type t :: %__MODULE__{
    name: atom(),
    label: String.t() | nil,
    field: atom() | nil,
    value: any() | Ash.Expr.t() | nil,
    format: format_type(),
    format_options: keyword(),
    width: float() | String.t() | nil,
    min_width: float() | String.t() | nil,
    max_width: float() | String.t() | nil,
    alignment: alignment(),
    vertical_alignment: vertical_alignment(),
    aggregate: aggregate_type() | nil,
    aggregate_options: keyword(),
    visible: boolean() | Ash.Expr.t(),
    style: map(),
    header_style: map(),
    footer_style: map(),
    on_render: {module(), atom(), list()} | nil,
    sortable: boolean(),
    sort_field: atom() | nil,
    word_wrap: boolean(),
    truncate: pos_integer() | nil
  }
  
  @doc """
  Creates a new column struct with default values.
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) do
    struct(
      __MODULE__,
      default_values()
      |> Keyword.merge(opts)
      |> Keyword.put(:name, name)
    )
  end
  
  @doc """
  Returns the default values for a column.
  """
  @spec default_values() :: keyword()
  def default_values do
    [
      format: :text,
      format_options: [],
      alignment: :left,
      vertical_alignment: :middle,
      aggregate_options: [],
      visible: true,
      style: %{},
      header_style: %{},
      footer_style: %{},
      sortable: false,
      word_wrap: false
    ]
  end
  
  @doc """
  Validates a column struct.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{} = column) do
    with :ok <- validate_name(column),
         :ok <- validate_data_source(column),
         :ok <- validate_format(column),
         :ok <- validate_alignment(column),
         :ok <- validate_aggregate(column),
         :ok <- validate_width(column) do
      {:ok, column}
    end
  end
  
  defp validate_name(%{name: nil}), do: {:error, "Column name is required"}
  defp validate_name(%{name: name}) when is_atom(name), do: :ok
  defp validate_name(_), do: {:error, "Column name must be an atom"}
  
  defp validate_data_source(%{field: nil, value: nil}), 
    do: {:error, "Column must have either a field or value"}
  defp validate_data_source(%{field: field}) when is_atom(field), do: :ok
  defp validate_data_source(%{value: _}), do: :ok
  defp validate_data_source(_), do: {:error, "Column field must be an atom"}
  
  defp validate_format(%{format: format}) do
    if format in format_types() do
      :ok
    else
      {:error, "Invalid column format"}
    end
  end
  
  defp validate_alignment(%{alignment: align, vertical_alignment: valign}) 
    when align in [:left, :center, :right, :justify] and 
         valign in [:top, :middle, :bottom], do: :ok
  defp validate_alignment(_), do: {:error, "Invalid alignment settings"}
  
  defp validate_aggregate(%{aggregate: nil}), do: :ok
  defp validate_aggregate(%{aggregate: agg}) do
    if agg in aggregate_types() do
      :ok
    else
      {:error, "Invalid aggregate type"}
    end
  end
  
  defp validate_width(%{width: nil}), do: :ok
  defp validate_width(%{width: width}) when is_number(width) and width > 0, do: :ok
  defp validate_width(%{width: width}) when is_binary(width) do
    if String.match?(width, ~r/^\d+(%|px|em|rem)?$/), do: :ok, else: {:error, "Invalid width format"}
  end
  defp validate_width(_), do: {:error, "Width must be a positive number or valid CSS width string"}
  
  @doc """
  Returns all valid format types.
  """
  @spec format_types() :: [format_type()]
  def format_types do
    [:text, :number, :currency, :percentage, :date, :datetime, :boolean, :custom]
  end
  
  @doc """
  Returns all valid aggregate types.
  """
  @spec aggregate_types() :: [aggregate_type()]
  def aggregate_types do
    [:count, :sum, :avg, :min, :max, :first, :last, :list]
  end
  
  @doc """
  Formats a value according to the column's format settings.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (passed in context)
  * `:time_zone` - The time zone for datetime formatting (passed in context)
  """
  @spec format_value(t(), any(), keyword()) :: String.t()
  def format_value(%__MODULE__{format: format, format_options: opts}, value, context \\ []) do
    locale = Keyword.get(context, :locale, "en")
    time_zone = Keyword.get(context, :time_zone)
    
    # Merge column options with context
    format_opts = Keyword.merge(opts, [locale: locale, time_zone: time_zone])
    
    case format do
      :text -> 
        to_string(value)
        
      :number -> 
        case AshReports.Formatter.format_number(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :currency -> 
        case AshReports.Formatter.format_currency(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :percentage -> 
        case AshReports.Formatter.format_percentage(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :date -> 
        case AshReports.Formatter.format_date(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :datetime -> 
        case AshReports.Formatter.format_datetime(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :boolean -> 
        case AshReports.Formatter.format_boolean(value, format_opts) do
          {:ok, formatted} -> formatted
          {:error, _} -> to_string(value)
        end
        
      :custom -> 
        to_string(value)
    end
  end
  
  
  @doc """
  Returns the effective label for the column.
  """
  @spec get_label(t()) :: String.t()
  def get_label(%__MODULE__{label: nil, name: name}), do: humanize(name)
  def get_label(%__MODULE__{label: label}), do: label
  
  defp humanize(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  @doc """
  Returns the field to use for sorting.
  """
  @spec get_sort_field(t()) :: atom() | nil
  def get_sort_field(%__MODULE__{sortable: false}), do: nil
  def get_sort_field(%__MODULE__{sortable: true, sort_field: field}) when not is_nil(field), do: field
  def get_sort_field(%__MODULE__{sortable: true, field: field}), do: field
  def get_sort_field(_), do: nil
end