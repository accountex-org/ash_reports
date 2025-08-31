defprotocol AshReports.Formattable do
  @moduledoc """
  Protocol for determining format types and applying formatting to different data types.

  This protocol provides a clean, extensible way to handle type detection and formatting
  for various data types in AshReports.
  """

  @typedoc "Format type for different data types"
  @type format_type ::
          :number
          | :currency
          | :percentage
          | :date
          | :time
          | :datetime
          | :boolean
          | :string
          | :custom

  @doc """
  Determines the appropriate format type for a given value.
  """
  @spec format_type(term()) :: format_type()
  def format_type(value)

  @doc """
  Formats a value according to its type and the provided options.
  """
  @spec format(term(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format(value, options)
end

defimpl AshReports.Formattable, for: Integer do
  def format_type(_value), do: :number

  def format(value, options) do
    AshReports.Cldr.format_number(value, options)
  end
end

defimpl AshReports.Formattable, for: Float do
  def format_type(_value), do: :number

  def format(value, options) do
    AshReports.Cldr.format_number(value, options)
  end
end

defimpl AshReports.Formattable, for: Date do
  def format_type(_value), do: :date

  def format(value, options) do
    AshReports.Cldr.format_date(value, options)
  end
end

defimpl AshReports.Formattable, for: DateTime do
  def format_type(_value), do: :datetime

  def format(value, options) do
    AshReports.Cldr.format_datetime(value, options)
  end
end

defimpl AshReports.Formattable, for: NaiveDateTime do
  def format_type(_value), do: :datetime

  def format(value, options) do
    AshReports.Cldr.format_datetime(value, options)
  end
end

defimpl AshReports.Formattable, for: Time do
  def format_type(_value), do: :time

  def format(value, options) do
    AshReports.Cldr.format_time(value, options)
  end
end

defimpl AshReports.Formattable, for: Atom do
  def format_type(true), do: :boolean
  def format_type(false), do: :boolean
  def format_type(_value), do: :string

  def format(value, _options) when is_boolean(value) do
    {:ok, if(value, do: "true", else: "false")}
  end

  def format(value, _options) do
    {:ok, to_string(value)}
  end
end

defimpl AshReports.Formattable, for: BitString do
  def format_type(_value), do: :string

  def format(value, _options) do
    {:ok, value}
  end
end

defimpl AshReports.Formattable, for: Any do
  def format_type(_value), do: :string

  def format(value, _options) do
    {:ok, to_string(value)}
  end
end
