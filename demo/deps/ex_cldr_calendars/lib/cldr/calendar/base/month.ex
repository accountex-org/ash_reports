defmodule Cldr.Calendar.Base.Month do
  @moduledoc false

  alias Cldr.Calendar.Config
  alias Cldr.Calendar.Base
  alias Calendar.ISO
  alias Cldr.Math

  import Cldr.Calendar,
    only: [
      missing_date_error: 4,
      missing_year_month_error: 3,
      missing_month_error: 2,
      missing_year_error: 2
    ]

  @days_in_week 7
  @quarters_in_year 4
  @months_in_quarter 3
  @months_in_gregorian_year 12
  @weeks_in_quarter 13
  @iso_week_first_day 1
  @iso_week_min_days 4
  @january 1

  # Whether to coerce valid date with plus/3 for
  # years and months (days, weeks dont ever require
  # coercion).
  @default_coercion Cldr.Calendar.default_coercion()

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      @options options
      @before_compile Cldr.Calendar.Compiler.Month
    end
  end

  defguard is_date(year, month, day)
           when is_integer(year) and is_integer(month) and is_integer(day)

  defguard is_date(date)
           when is_map_key(date, :year) and is_map_key(date, :month) and is_map_key(date, :day)

  def valid_date?(year, month, day, %Config{month_of_year: 1}) do
    Calendar.ISO.valid_date?(year, month, day)
  end

  def valid_date?(year, month, day, config) do
    {year, month, day} = date_to_iso_date(year, month, day, config)
    Calendar.ISO.valid_date?(year, month, day)
  end

  # Year of era assumes that the era transitions are always aligned
  # to the calendar year. But for 445 type calendar and country fiscal
  # calendars this is not necessarily true. So we have to decide whether
  # the beginning or ending Gregorian year is the year we consider.

  def year_of_era(year, %{year: :ending} = config) when is_integer(year) do
    {_, year} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :beginning} = config) when is_integer(year) do
    {year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority, month_of_year: starts} = config)
      when is_integer(year) and starts <= 6 do
    {year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority} = config) do
    {_, year} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def quarter_of_year(year, month, _day, config) when is_integer(year) and is_integer(month) do
    ceil(month / (months_in_year(year, config) / @quarters_in_year))
  end

  def quarter_of_year(year, month, _day, _config) do
    {:error, missing_year_month_error("quarter_of_year", year, month)}
  end

  def month_of_year(_year, month, _day, _config) when is_integer(month) do
    month
  end

  def month_of_year(_year, month, _day, _config) do
    {:error, missing_month_error("month_of_year", month)}
  end

  def week_of_year(year, month, day, %Config{day_of_week: :first} = config)
      when is_date(year, month, day) do
    this_day = date_to_iso_days(year, month, day, config)
    first_day = date_to_iso_days(year, 1, 1, config)
    week = div(this_day - first_day, @days_in_week) + 1
    {year, week}
  end

  def week_of_year(year, month, day, config) when is_date(year, month, day) do
    iso_days = date_to_iso_days(year, month, day, config)
    first_gregorian_day_of_year = Base.Week.first_gregorian_day_of_year(year, config)
    last_gregorian_day_of_year = Base.Week.last_gregorian_day_of_year(year, config)

    cond do
      iso_days < first_gregorian_day_of_year ->
        if Base.Week.long_year?(year - 1, config), do: {year - 1, 53}, else: {year - 1, 52}

      iso_days > last_gregorian_day_of_year ->
        {year + 1, 1}

      true ->
        week = div(iso_days - first_gregorian_day_of_year, @days_in_week) + 1
        {year, week}
    end
  end

  def week_of_year(year, month, day, _config) do
    {:error, missing_date_error("week_of_year", year, month, day)}
  end

  def iso_week_of_year(year, month, day) when is_date(year, month, day) do
    week_of_year(year, month, day, %Config{
      day_of_week: @iso_week_first_day,
      min_days_in_first_week: @iso_week_min_days,
      month_of_year: @january
    })
  end

  def iso_week_of_year(year, month, day) do
    {:error, missing_date_error("iso_week_of_year", year, month, day)}
  end

  def week_of_month(year, month, day, %Config{day_of_week: :first} = config)
      when is_date(year, month, day) do
    this_day = date_to_iso_days(year, month, day, config)
    first_day = date_to_iso_days(year, month, 1, config)
    week = div(this_day - first_day, @days_in_week) + 1
    {month, week}
  end

  def week_of_month(year, month, day, config) when is_date(year, month, day) do
    {_year, week} = week_of_year(year, month, day, config)
    {quarters, weeks_remaining_in_quarter} = Math.div_amod(week, @weeks_in_quarter)
    month_in_quarter = Base.Week.month_from_weeks(weeks_remaining_in_quarter, config)

    month = quarters * @months_in_quarter + month_in_quarter
    week = weeks_remaining_in_quarter - Base.Week.weeks_from_months(month_in_quarter - 1, config)

    {month, week}
  end

  def week_of_month(year, month, day, _config) do
    {:error, missing_date_error("week_of_month", year, month, day)}
  end

  def day_of_era(year, month, day, config) when is_date(year, month, day) do
    {year, month, day} = date_to_iso_date(year, month, day, config)
    Calendar.ISO.day_of_era(year, month, day)
  end

  def day_of_era(year, month, day, _config) do
    {:error, missing_date_error("day_of_era", year, month, day)}
  end

  def day_of_year(year, month, day, config) when is_date(year, month, day) do
    {iso_year, iso_month, iso_day} = date_to_iso_date(year, month, day, config)
    iso_days = Calendar.ISO.date_to_iso_days(iso_year, iso_month, iso_day)
    iso_days - first_gregorian_day_of_year(year, config) + 1
  end

  def day_of_year(year, month, day, _config) do
    {:error, missing_date_error("day_of_year", year, month, day)}
  end

  def day_of_week(year, month, day, config) when is_date(year, month, day) do
    {year, month, day} = date_to_iso_date(year, month, day, config)
    {day, _first, _last} = ISO.day_of_week(year, month, day, :default)
    day
  end

  def day_of_week(year, month, day, _config) do
    {:error, missing_date_error("day_of_week", year, month, day)}
  end

  def months_in_year(year, _config) when is_integer(year) do
    Calendar.ISO.months_in_year(year)
  end

  def months_in_year(year, _config) do
    {:error, missing_year_error("months_in_year", year)}
  end

  # If the weeks start on the first day of the calendar year
  # (which is unusual) then we will have a fractional last week
  # of the year of either 1 or 2 days (depending on leap year)

  def weeks_in_year(year, %Config{day_of_week: :first} = config) when is_integer(year) do
    first_day = first_gregorian_day_of_year(year, config)
    last_day = last_gregorian_day_of_year(year, config)

    case Cldr.Math.div_mod(last_day - first_day + 1, @days_in_week) do
      {weeks, 0} ->
        {weeks, @days_in_week}

      {weeks, days_in_last_week} ->
        {weeks + 1, days_in_last_week}
    end
  end

  # In all other cases, like the ISO calendar, there is a
  # designated day that starts the week. In this case the
  # weeks of a year do not align to the calendar year start
  # and end dates.

  def weeks_in_year(year, config) when is_integer(year) do
    if Base.Week.long_year?(year, config) do
      Base.Week.weeks_in_long_year()
    else
      Base.Week.weeks_in_normal_year()
    end
  end

  def weeks_in_year(year, _config) do
    {:error, missing_year_error("weeks_in_year", year)}
  end

  def days_in_year(year, config) when is_integer(year) do
    if leap_year?(year, config), do: 366, else: 365
  end

  def days_in_year(year, _config) do
    {:error, missing_year_error("days_in_year", year)}
  end

  def days_in_month(year, month, config) when is_integer(year) and is_integer(month) do
    {iso_year, iso_month, _day} = date_to_iso_date(year, month, 1, config)
    ISO.days_in_month(iso_year, iso_month)
  end

  def days_in_month(month, %{month_of_year: 1}) when is_integer(month) do
    case month do
      2 -> {:ambiguous, 28..29}
      month when month in [9, 4, 6, 11] -> 30
      _other -> 31
    end
  end

  def days_in_month(month, %{month_of_year: calendar_start_month}) when is_integer(month) do
    gregorian_month = calendar_month_to_gregorian_month(month, calendar_start_month)
    days_in_month(gregorian_month, %{month_of_year: 1})
  end

  def days_in_month(month, _config) do
    {:error, missing_year_error("days_in_month", month)}
  end

  def calendar_month_to_gregorian_month(month, calendar_start_month) do
    Cldr.Math.amod(calendar_start_month - 1 + month, @months_in_gregorian_year)
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _week) do
    @days_in_week
  end

  def year(year, config) do
    calendar = config.calendar
    last_month = calendar.months_in_year(year)
    days_in_last_month = calendar.days_in_month(year, last_month)

    with {:ok, start_date} <- Date.new(year, 1, 1, config.calendar),
         {:ok, end_date} <- Date.new(year, last_month, days_in_last_month, config.calendar) do
      Date.range(start_date, end_date)
    end
  end

  def quarter(year, quarter, config) do
    if quarter in 1..@quarters_in_year do
      months_in_quarter = div(months_in_year(year, config), @quarters_in_year)
      starting_month = months_in_quarter * (quarter - 1) + 1
      starting_day = 1

      ending_month = starting_month + months_in_quarter - 1
      ending_day = days_in_month(year, ending_month, config)

      with {:ok, start_date} <- Date.new(year, starting_month, starting_day, config.calendar),
           {:ok, end_date} <- Date.new(year, ending_month, ending_day, config.calendar) do
        Date.range(start_date, end_date)
      end
    else
      {:error, :invalid_date}
    end
  end

  def month(year, month, config) do
    if month in 1..months_in_year(year, month) do
      starting_day = 1
      ending_day = days_in_month(year, month, config)

      with {:ok, start_date} <- Date.new(year, month, starting_day, config.calendar),
           {:ok, end_date} <- Date.new(year, month, ending_day, config.calendar) do
        Date.range(start_date, end_date)
      end
    else
      {:error, :invalid_date}
    end
  end

  # When the weeks starts on the first day of the year we will have
  # a final partial week of one of two days.

  def week(year, week, %Config{day_of_week: :first} = config) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)

    if week in 1..weeks_in_year do
      first_day = first_gregorian_day_of_year(year, config)
      last_day = last_gregorian_day_of_year(year, config)

      start_day = first_day + (week - 1) * @days_in_week
      end_day = min(start_day + @days_in_week - 1, last_day)

      {year, month, day} = date_from_iso_days(start_day, config)
      {:ok, start_date} = Date.new(year, month, day, config.calendar)

      {year, month, day} = date_from_iso_days(end_day, config)
      {:ok, end_date} = Date.new(year, month, day, config.calendar)

      Date.range(start_date, end_date)
    else
      {:error, :invalid_date}
    end
  end

  # For all other configurations where the week starts on a fixed
  # day we will have a fixed number of weeks (52 or 53) each of 7
  # days. But the range of dates for a week may fall outside the
  # calendar year.

  def week(year, week, config) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)

    if week in 1..weeks_in_year do
      starting_day =
        Base.Week.first_gregorian_day_of_year(year, config) +
          Cldr.Calendar.weeks_to_days(week - 1)

      ending_day = starting_day + days_in_week() - 1

      with {year, month, day} <- date_from_iso_days(starting_day, config),
           {:ok, start_date} <- Date.new(year, month, day, config.calendar),
           {year, month, day} <- date_from_iso_days(ending_day, config),
           {:ok, end_date} <- Date.new(year, month, day, config.calendar) do
        Date.range(start_date, end_date)
      end
    else
      {:error, :invalid_date}
    end
  end

  def plus(year, month, day, config, :years, years, options) do
    new_year = year + years
    coerce? = Keyword.get(options, :coerce, @default_coercion)
    {new_month, new_day} = Cldr.Calendar.month_day(new_year, month, day, config.calendar, coerce?)
    {new_year, new_month, new_day}
  end

  def plus(year, month, day, config, :quarters, quarters, options) do
    months = quarters * @months_in_quarter
    plus(year, month, day, config, :months, months, options)
  end

  def plus(year, month, day, config, :months, months, options) do
    months_in_year = months_in_year(year, config)

    {year_increment, new_month} =
      case Cldr.Math.div_amod(month + months, months_in_year) do
        {year_increment, new_month} when new_month > 0 ->
          {year_increment, new_month}

        {year_increment, new_month} ->
          {year_increment - 1, months_in_year + new_month}
      end

    new_year = year + year_increment

    new_day =
      if Keyword.get(options, :coerce, @default_coercion) do
        max_new_day = days_in_month(new_year, new_month, config)
        min(day, max_new_day)
      else
        day
      end

    {new_year, new_month, new_day}
  end

  def plus(year, month, day, config, :weeks, weeks, _options) do
    year
    |> date_to_iso_days(month, day, config)
    |> Kernel.+(Cldr.Calendar.weeks_to_days(weeks))
    |> date_from_iso_days(config)
  end

  def plus(year, month, day, config, :days, days, _options) do
    year
    |> date_to_iso_days(month, day, config)
    |> Kernel.+(days)
    |> date_from_iso_days(config)
  end

  def first_gregorian_day_of_year(year, %Config{month_of_year: 1}) do
    ISO.date_to_iso_days(year, 1, 1)
  end

  def first_gregorian_day_of_year(year, %Config{month_of_year: first_month} = config) do
    {beginning_year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)
    ISO.date_to_iso_days(beginning_year, first_month, 1)
  end

  def last_gregorian_day_of_year(year, %Config{month_of_year: first_month} = config) do
    {_, ending_year} = Cldr.Calendar.start_end_gregorian_years(year, config)
    last_month = Math.amod(first_month - 1, ISO.months_in_year(ending_year))
    last_day = ISO.days_in_month(ending_year, last_month)
    ISO.date_to_iso_days(ending_year, last_month, last_day)
  end

  def leap_year?(year, %Config{month_of_year: 1}) do
    ISO.leap_year?(year)
  end

  def leap_year?(year, config) do
    days_in_year =
      last_gregorian_day_of_year(year, config) - first_gregorian_day_of_year(year, config) + 1

    days_in_year == 366
  end

  def date_to_iso_days(year, month, day, config) do
    {days, _day_fraction} = naive_datetime_to_iso_days(year, month, day, 0, 0, 0, {0, 6}, config)
    days
  end

  def date_from_iso_days(iso_day_number, config) do
    {year, month, day, _, _, _, _} = naive_datetime_from_iso_days(iso_day_number, config)
    {year, month, day}
  end

  def naive_datetime_from_iso_days(iso_day_number, config) when is_integer(iso_day_number) do
    naive_datetime_from_iso_days({iso_day_number, {0, 6}}, config)
  end

  def naive_datetime_from_iso_days({days, day_fraction}, config) do
    {year, month, day} = Calendar.ISO.date_from_iso_days(days)
    {year, month, day} = date_from_iso_date(year, month, day, config)
    {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
    {year, month, day, hour, minute, second, microsecond}
  end

  def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond, config) do
    {year, month, day} = date_to_iso_date(year, month, day, config)
    ISO.naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond)
  end

  @compile {:inline, date_to_iso_date: 4}
  def date_to_iso_date(year, month, day, %Config{} = config) do
    slide = slide(config)
    {iso_year, iso_month} = add_month(year, month, -slide)
    {iso_year, iso_month, day}
  end

  @compile {:inline, date_from_iso_date: 4}
  def date_from_iso_date(iso_year, iso_month, day, %Config{} = config) do
    slide = slide(config)
    {year, month} = add_month(iso_year, iso_month, slide)
    {year, month, day}
  end

  defp add_month(year, month, add) do
    calculated_month = month + add
    month = Math.amod(calculated_month, ISO.months_in_year(year))

    cond do
      calculated_month < 1 -> {year - 1, month}
      calculated_month > ISO.months_in_year(year) -> {year + 1, month}
      true -> {year, month}
    end
  end

  @random_year 2000
  defp slide(%Config{month_of_year: month} = config) do
    {starts, _ends} = Cldr.Calendar.start_end_gregorian_years(@random_year, config)
    direction = if starts < @random_year, do: -1, else: +1
    month = Math.amod((month - 1) * direction, ISO.months_in_year(starts))
    if month == 12, do: 0, else: month * direction * -1
  end
end
