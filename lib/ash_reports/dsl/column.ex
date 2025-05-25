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
      opts
      |> Keyword.put(:name, name)
      |> Keyword.merge(default_values())
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
  
  defp validate_format(%{format: format}) when format in format_types(), do: :ok
  defp validate_format(_), do: {:error, "Invalid column format"}
  
  defp validate_alignment(%{alignment: align, vertical_alignment: valign}) 
    when align in [:left, :center, :right, :justify] and 
         valign in [:top, :middle, :bottom], do: :ok
  defp validate_alignment(_), do: {:error, "Invalid alignment settings"}
  
  defp validate_aggregate(%{aggregate: nil}), do: :ok
  defp validate_aggregate(%{aggregate: agg}) when agg in aggregate_types(), do: :ok
  defp validate_aggregate(_), do: {:error, "Invalid aggregate type"}
  
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
  """
  @spec format_value(t(), any()) :: String.t()
  def format_value(%__MODULE__{format: format, format_options: opts}, value) do
    case format do
      :text -> to_string(value)
      :number -> format_number(value, opts)
      :currency -> format_currency(value, opts)
      :percentage -> format_percentage(value, opts)
      :date -> format_date(value, opts)
      :datetime -> format_datetime(value, opts)
      :boolean -> format_boolean(value, opts)
      :custom -> value
    end
  end
  
  defp format_number(nil, _), do: ""
  defp format_number(value, opts) when is_number(value) do
    precision = Keyword.get(opts, :precision, 2)
    delimiter = Keyword.get(opts, :delimiter, ",")
    separator = Keyword.get(opts, :separator, ".")
    
    value
    |> Float.round(precision)
    |> to_string()
    |> add_thousands_separator(delimiter, separator)
  end
  defp format_number(value, _), do: to_string(value)
  
  defp format_currency(nil, _), do: ""
  defp format_currency(value, opts) when is_number(value) do
    symbol = Keyword.get(opts, :symbol, "$")
    position = Keyword.get(opts, :position, :before)
    
    formatted = format_number(value, opts)
    
    case position do
      :before -> "#{symbol}#{formatted}"
      :after -> "#{formatted}#{symbol}"
    end
  end
  defp format_currency(value, _), do: to_string(value)
  
  defp format_percentage(nil, _), do: ""
  defp format_percentage(value, opts) when is_number(value) do
    multiply = Keyword.get(opts, :multiply, true)
    precision = Keyword.get(opts, :precision, 2)
    
    percentage_value = if multiply, do: value * 100, else: value
    
    "#{Float.round(percentage_value, precision)}%"
  end
  defp format_percentage(value, _), do: to_string(value)
  
  defp format_date(nil, _), do: ""
  defp format_date(%Date{} = date, opts) do
    format = Keyword.get(opts, :format, "{YYYY}-{0M}-{0D}")
    Calendar.strftime(date, format)
  end
  defp format_date(value, _), do: to_string(value)
  
  defp format_datetime(nil, _), do: ""
  defp format_datetime(%DateTime{} = datetime, opts) do
    format = Keyword.get(opts, :format, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
    Calendar.strftime(datetime, format)
  end
  defp format_datetime(%NaiveDateTime{} = datetime, opts) do
    format = Keyword.get(opts, :format, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
    Calendar.strftime(datetime, format)
  end
  defp format_datetime(value, _), do: to_string(value)
  
  defp format_boolean(true, opts), do: Keyword.get(opts, :true_text, "Yes")
  defp format_boolean(false, opts), do: Keyword.get(opts, :false_text, "No")
  defp format_boolean(nil, opts), do: Keyword.get(opts, :nil_text, "")
  defp format_boolean(value, _), do: to_string(value)
  
  defp add_thousands_separator(string, delimiter, separator) do
    [integer_part | decimal_parts] = String.split(string, ".")
    
    formatted_integer = integer_part
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(delimiter)
    |> String.reverse()
    
    case decimal_parts do
      [] -> formatted_integer
      _ -> "#{formatted_integer}#{separator}#{Enum.join(decimal_parts, ".")}"
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
  def get_sort_field(%__MODULE__{sort_field: field}) when not is_nil(field), do: field
  def get_sort_field(%__MODULE__{field: field}), do: field
end