defmodule Cldr.Calendar.Config do
  @moduledoc """
  Defines the configuration for a calendar.

  See `Cldr.Calendar.new/3` for usage details.

  """
  defstruct calendar: nil,

            # A default backend for this
            # calendar
            cldr_backend: nil,

            # Each quarter has three
            # 'months` each of 13 weeks
            # in either of a 4,4,5; 4,5,4
            # of 5,4,4 layout
            weeks_in_month: [4, 4, 5],

            # Indicates if the anchor
            # represents the beginning
            # of the year or the end
            begins_or_ends: :begins,

            # Calendar begins on the
            # :first, :last or :nearest
            first_or_last: :first,

            # Year begins on this day
            # Use :first to mean the day
            # day of the week on which the
            # first day of the year occurs
            # The functions `Cldr.Calendar.monday()`
            # etc can be used
            day_of_week: 1,

            # Year begins in this Gregorian month
            month_of_year: 1,

            # The year of the last_day or first_day
            # is either the year with the :majority
            # of months or the :beginning year
            # or :ending year
            year: :majority,

            # First week has at least
            # this many days in current
            # year
            min_days_in_first_week: 1,

            # The CLDR calendar type
            cldr_calendar_type: :gregorian

  @typedoc """
  Defines the struct type for a calendar configuration
  """
  @type t() :: %__MODULE__{
          calendar: atom(),
          cldr_backend: Cldr.backend() | nil,
          cldr_calendar_type: :gregorian | :japanese,
          weeks_in_month: list(pos_integer()),
          begins_or_ends: :begins | :ends,
          first_or_last: :first | :last,
          day_of_week: Cldr.Calendar.day_of_week() | :first,
          month_of_year: pos_integer(),
          year: :majority | :starts | :ends,
          min_days_in_first_week: 1..7
        }

  @doc false
  def extract_options(options) do
    invalidate_old_options!(options)
    detect_invalid_options!(options)

    default_backend = Application.get_env(Cldr.Config.app_name(), :default_backend)

    backend = Keyword.get(options, :backend, default_backend)

    backend = if backend && Cldr.Code.ensure_compiled?(backend), do: backend, else: nil

    %__MODULE__{
      calendar: Keyword.get(options, :calendar),
      cldr_backend: backend,
      cldr_calendar_type: Keyword.get(options, :cldr_calendar_type, :gregorian),
      min_days_in_first_week: min_days_for_locale(backend, options),
      day_of_week: first_day_for_locale(backend, options),
      year: Keyword.get(options, :year, :majority),
      month_of_year: Keyword.get(options, :month_of_year, 1),
      first_or_last: Keyword.get(options, :first_or_last, :first),
      begins_or_ends: Keyword.get(options, :begins_or_ends, :begins),
      weeks_in_month: Keyword.get(options, :weeks_in_month, [4, 5, 4])
    }
  end

  def min_days_for_locale(nil, options) do
    default =
      if locale = Keyword.get(options, :locale) do
        Cldr.Calendar.min_days_for_locale(locale)
      else
        1
      end

    Keyword.get(options, :min_days_in_first_week, default)
  end

  def min_days_for_locale(backend, options) do
    locale = Keyword.get(options, :locale, backend.get_locale())
    Keyword.get(options, :min_days_in_first_week, Cldr.Calendar.min_days_for_locale(locale))
  end

  def first_day_for_locale(nil, options) do
    default =
      if locale = Keyword.get(options, :locale) do
        Cldr.Calendar.first_day_for_locale(locale)
      else
        1
      end

    Keyword.get(options, :day_of_week, default)
  end

  def first_day_for_locale(backend, options) do
    locale = Keyword.get(options, :locale, backend.get_locale())
    Keyword.get(options, :day_of_week, Cldr.Calendar.first_day_for_locale(locale))
  end

  @valid_weeks_in_month [[4, 4, 5], [4, 5, 4], [5, 4, 4]]
  @valid_year [:majority, :beginning, :ending]
  @valid_cldr_calendar_types [:gregorian, :japanese]

  @doc false
  def validate_config(config, calendar_type) do
    with :ok <-
           validate_day(config, calendar_type),
         :ok <-
           assert(config.month_of_year in 1..12, month_error(config.month_of_year)),
         :ok <-
           assert(config.year in @valid_year, year_error(config.year)),
         :ok <-
           assert(
             config.cldr_calendar_type in @valid_cldr_calendar_types,
             calendar_type_error(config.cldr_calendar_type)
           ),
         :ok <-
           assert(
             config.min_days_in_first_week in 1..7,
             min_days_for_locale_error(config.min_days_in_first_week)
           ),
         :ok <-
           assert(
             config.first_or_last in [:first, :last],
             first_or_last_error(config.first_or_last)
           ),
         :ok <-
           assert(
             config.begins_or_ends in [:begins, :ends],
             begins_or_ends_error(config.begins_or_ends)
           ),
         :ok <-
           assert(
             config.weeks_in_month in @valid_weeks_in_month,
             weeks_in_month_error(config.weeks_in_month)
           ) do
      {:ok, config}
    end
  end

  @doc false
  def validate_config!(config, calendar_type) do
    case validate_config(config, calendar_type) do
      {:ok, config} -> config
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp invalidate_old_options!(options) do
    if options[:day],
      do: raise(ArgumentError, "Option :day is replaced with :day_of_week")

    if options[:month],
      do: raise(ArgumentError, "Option :month is replaced with :month_of_year")

    if options[:min_days],
      do: raise(ArgumentError, "Option :min_days is replaced with :min_days_in_first_week")
  end

  defp valid_options do
    %__MODULE__{}
    |> Map.delete(:__struct__)
    |> Map.keys()
    |> List.insert_at(0, :locale)
  end

  defp detect_invalid_options!(options) do
    case Enum.filter(options, fn {key, _} -> key not in valid_options() end) do
      [] ->
        options

      invalid_options ->
        raise ArgumentError,
              "Invalid options #{inspect(invalid_options)} found.  Valid options are #{inspect(valid_options())}"
    end
  end

  defp validate_day(config, :week) do
    assert(config.day_of_week in 1..7, day_error(config.day_of_week))
  end

  defp validate_day(config, :month) do
    assert(
      config.day_of_week in 1..7 or config.day_of_week == :first,
      day_error(config.day_of_week)
    )
  end

  defp assert(true, _) do
    :ok
  end

  defp assert(false, message) do
    {:error, message}
  end

  defp day_error(day) do
    ":day_of_week must be in the range 1..7. Found #{inspect(day)}."
  end

  defp month_error(month) do
    ":month_of_year must be in the range 1..12. Found #{inspect(month)}."
  end

  defp year_error(year) do
    ":year must be either :beginning, :ending or :majority. Found #{inspect(year)}."
  end

  defp calendar_type_error(type) do
    ":cldr_calendar_type must be either :gregorian or :japanese. Found #{inspect(type)}."
  end

  defp min_days_for_locale_error(min_days) do
    ":min_days_in_first_week must be in the range 1..7. Found #{inspect(min_days)}."
  end

  defp first_or_last_error(first_or_last) do
    ":first_or_last must be :first or :last. Found #{inspect(first_or_last)}."
  end

  defp begins_or_ends_error(begins_or_ends) do
    ":begins_or_ends must be :begins or :ends. Found #{inspect(begins_or_ends)}."
  end

  defp weeks_in_month_error(weeks_in_month) do
    ":weeks_in_month must be [4,4,5], [4,5,4] or [5,4,4]. Found #{inspect(weeks_in_month)}"
  end
end
