defmodule Cldr.Calendar.Base.Week do
  @moduledoc false

  alias Cldr.Calendar.Config
  alias Cldr.Calendar.Base.Month
  alias Calendar.ISO
  alias Cldr.Math

  import Cldr.Calendar,
    only: [missing_date_error: 4, missing_day_error: 2, missing_year_error: 2]

  @days_in_week 7
  @weeks_in_quarter 13
  @months_in_quarter 3
  @months_in_year 12
  @weeks_in_long_year 53
  @weeks_in_normal_year 52
  @quarters_in_year 4

  # Whether to coerce valid date with plus/3 for
  # years and months (days, weeks dont ever require
  # coercion).
  @default_coercion Cldr.Calendar.default_coercion()

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      @options options
      @before_compile Cldr.Calendar.Compiler.Week
    end
  end

  defguard is_date(year, week, day)
           when is_integer(year) and is_integer(week) and is_integer(day)

  defguard is_date(date)
           when is_map_key(date, :year) and is_map_key(date, :month) and is_map_key(date, :day)

  def valid_date?(year, week, day, config) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)
    week in 1..weeks_in_year and day in 1..days_in_week()
  end

  # Year of era assumes that the era transitions are always aligned
  # to the calendar year. But for 445 type calendar and country fiscal
  # calendars this is not necessarily true. So we have to decide whether
  # the beginning or ending Gregorian year is the year we consider.

  def year_of_era(year, %{year: :ending} = config) do
    {_, year} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :beginning} = config) do
    {year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority, month_of_year: starts} = config) when starts <= 6 do
    {year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority} = config) do
    {_, year} = Cldr.Calendar.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  # Quarters are 13 weeks but if there
  # are 53 weeks in a year then 4th
  # quarter is longer
  def quarter_of_year(_year, @weeks_in_long_year, _day, _config) do
    4
  end

  def quarter_of_year(_year, week, _day, _config) do
    div(week - 1, @weeks_in_quarter) + 1
  end

  def month_of_year(_year, @weeks_in_long_year, _day, _config) do
    +12
  end

  def month_of_year(year, week, day, %Config{weeks_in_month: weeks_in_month} = config) do
    quarter = quarter_of_year(year, week, day, config)
    months_in_prior_quarters = (quarter - 1) * @months_in_quarter

    week_in_quarter = Math.amod(week, @weeks_in_quarter)
    [m1, m2, _m3] = weeks_in_month

    month_in_quarter =
      cond do
        week_in_quarter <= m1 -> 1
        week_in_quarter <= m1 + m2 -> 2
        true -> 3
      end

    months_in_prior_quarters + month_in_quarter
  end

  def week_of_year(year, week, _day, _config) when is_integer(year) and is_integer(week) do
    {year, week}
  end

  def week_of_year(year, month, day, _config) do
    {:error, missing_date_error("week_of_year", year, month, day)}
  end

  def iso_week_of_year(year, week, day, config) when is_date(year, week, day) do
    with {:ok, date} <- Date.new(year, week, day, config.calendar) do
      {:ok, %{year: year, month: month, day: day}} = Date.convert(date, Cldr.Calendar.Gregorian)
      Cldr.Calendar.Gregorian.iso_week_of_year(year, month, day)
    end
  end

  def iso_week_of_year(year, week, day) do
    {:error, missing_date_error("iso_week_of_year", year, week, day)}
  end

  def week_of_month(year, week, day, config) when is_date(year, week, day) do
    month = month_of_year(year, week, day, config)
    %Date.Range{first: first} = month(year, month, config)
    {month, week - first.month + 1}
  end

  def week_of_month(year, week, day, _config) do
    {:error, missing_date_error("week_of_month", year, week, day)}
  end

  def day_of_era(year, week, day, config) when is_date(year, week, day) do
    with {:ok, date} <- Date.new(year, week, day, config.calendar) do
      {:ok, %{year: year, month: month, day: day}} = Date.convert(date, Calendar.ISO)
      Calendar.ISO.day_of_era(year, month, day)
    end
  end

  def day_of_era(year, week, day, _config) do
    {:error, missing_date_error("day_of_era", year, week, day)}
  end

  def day_of_year(year, week, day, config) when is_date(year, week, day) do
    start_of_year = first_gregorian_day_of_year(year, config)
    this_day = first_gregorian_day_of_year(year, config) + week_to_days(week) + day
    trunc(this_day - start_of_year + 1)
  end

  def day_of_year(year, week, day, _config) do
    {:error, missing_date_error("day_of_year", year, week, day)}
  end

  def day_of_week(_year, _week, day, %{first_or_last: :first} = config) when is_integer(day) do
    first_day = config.day_of_week
    Math.amod(first_day + day - 1, days_in_week())
  end

  def day_of_week(_year, _week, day, %{first_or_last: :last} = config) when is_integer(day) do
    last_day = config.day_of_week
    Math.amod(last_day + day, days_in_week())
  end

  def day_of_week(_year, _week, day, _config) do
    {:error, missing_day_error("day_of_week", day)}
  end

  def months_in_year(year, _config) when is_integer(year) do
    Calendar.ISO.months_in_year(year)
  end

  def months_in_year(year, _config) do
    {:error, missing_year_error("months_in_year", year)}
  end

  def weeks_in_year(year, config) when is_integer(year) do
    if long_year?(year, config), do: weeks_in_long_year(), else: weeks_in_normal_year()
  end

  def weeks_in_year(year, _config) do
    {:error, missing_year_error("weeks_in_year", year)}
  end

  def weeks_in_long_year do
    {@weeks_in_long_year, @days_in_week}
  end

  def weeks_in_normal_year do
    {@weeks_in_normal_year, @days_in_week}
  end

  def weeks_in_quarter(year, quarter, config) do
    if quarter == @quarters_in_year && long_year?(year, config) do
      @weeks_in_quarter + 1
    else
      @weeks_in_quarter
    end
  end

  def days_in_year(year, config) when is_integer(year) do
    if long_year?(year, config) do
      @weeks_in_long_year * @days_in_week
    else
      @weeks_in_normal_year * @days_in_week
    end
  end

  def days_in_year(year, _config) do
    {:error, missing_year_error("days_in_year", year)}
  end

  # The last month may be a long month so the
  # days in month might be a week longer
  def days_in_month(year, @months_in_year, config) do
    %Config{weeks_in_month: [_, _, weeks_in_last_month]} = config
    weeks = if long_year?(year, config), do: weeks_in_last_month + 1, else: weeks_in_last_month
    trunc(weeks * days_in_week())
  end

  def days_in_month(_year, month, config) do
    %Config{weeks_in_month: weeks_in_month} = config
    month_in_quarter = Math.amod(rem(month, @months_in_quarter), @months_in_quarter)
    (Enum.at(weeks_in_month, month_in_quarter - 1) * days_in_week()) |> trunc()
  end

  # If the month is the last month of the year then it will be different
  # number of days in a long year.
  @any_year 2000

  def days_in_month(month, %Config{weeks_in_month: [_, _, weeks_in_last_month]} = config) do
    if month == @months_in_year do
      long_year_days = trunc((weeks_in_last_month + 1) * days_in_week())
      short_year_days = trunc(weeks_in_last_month * days_in_week())
      {:ambiguous, [short_year_days, long_year_days]}
    else
      days_in_month(@any_year, month, config)
    end
  end

  def days_in_month(month, _config) do
    {:error, missing_year_error("days_in_month", month)}
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _week) do
    @days_in_week
  end

  def year(year, config) do
    with {:ok, first_day} <- Date.new(year, 1, 1, config.calendar),
         {weeks_in_year, _} <- weeks_in_year(year, config),
         {:ok, last_day} <- Date.new(year, weeks_in_year, days_in_week(), config.calendar) do
      Date.range(first_day, last_day)
    end
  end

  def quarter(year, quarter, config) do
    if quarter in 1..@quarters_in_year do
      starting_week = (quarter - 1) * @weeks_in_quarter + 1
      ending_week = starting_week + weeks_in_quarter(year, quarter, config) - 1

      with {:ok, first_day} <- Date.new(year, starting_week, 1, config.calendar),
           {:ok, last_day} <- Date.new(year, ending_week, days_in_week(), config.calendar) do
        Date.range(first_day, last_day)
      end
    else
      {:error, :invalid_date}
    end
  end

  def month(year, month, %{weeks_in_month: weeks_in_month} = config) do
    if month in 1..months_in_year(year, month) do
      months_prior_in_quarter = rem(month - 1, @months_in_quarter)
      prior_quarters = Month.quarter_of_year(year, month, 1, config) - 1
      quarter_weeks_prior = prior_quarters * @weeks_in_quarter

      weeks_prior_in_quarter =
        weeks_in_month
        |> Enum.take(months_prior_in_quarter)
        |> Enum.sum()

      weeks_in_month =
        Enum.at(weeks_in_month, months_prior_in_quarter) +
          maybe_extra_week_for_long_year(year, month, config)

      first_week = quarter_weeks_prior + weeks_prior_in_quarter + 1
      last_week = first_week + weeks_in_month - 1

      {:ok, start_of_month} = Date.new(year, first_week, 1, config.calendar)
      {:ok, end_of_month} = Date.new(year, last_week, days_in_week(), config.calendar)

      Date.range(start_of_month, end_of_month)
    else
      {:error, :invalid_date}
    end
  end

  def week(year, week, config) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)

    if week in 1..weeks_in_year do
      with {:ok, first_day} <- Date.new(year, week, 1, config.calendar),
           {:ok, last_day} <- Date.new(year, week, days_in_week(), config.calendar) do
        Date.range(first_day, last_day)
      end
    else
      {:error, :invalid_date}
    end
  end

  def plus(year, week, day, config, :years, years, options) do
    new_year = year + years
    coerce? = Keyword.get(options, :coerce, @default_coercion)
    {new_week, new_day} = Cldr.Calendar.month_day(new_year, week, day, config.calendar, coerce?)
    {new_year, new_week, new_day}
  end

  def plus(year, week, day, config, :quarters, quarters, options) do
    plus(year, week, day, config, :months, quarters * @months_in_quarter, options)
  end

  def plus(year, week, day, _config, :months, 0, _options) do
    {year, week, day}
  end

  # When adding a month the process is
  # 1. Capture the day of the month
  # 2. Get the first day of that month
  # 3. Add the number of days in that month leaving us
  #    with the first day of the next month
  # 4. Add back the day of the month, potentially
  #    coercing the last day of the month
  def plus(year, week, day, config, :months, 1 = n, options) do
    day_of_month = day_of_month(year, week, day, config)
    {year, week, day} = first_day_of_month(year, week, day, config)

    month_of_year = month_of_year(year, week, day, config)
    month_in_quarter = month_in_quarter(week, config)

    weeks_to_add =
      slice_weeks(month_in_quarter - 1, n, config) +
        maybe_extra_week_for_long_year(year, month_of_year, config)

    {weeks_in_year, _} = weeks_in_year(year, config)
    {year_increment, week} = Cldr.Math.div_mod(week + weeks_to_add, weeks_in_year)
    add_days(year + year_increment, week, day, day_of_month - 1, config, options)
  end

  # WHen subtracting a month the process is
  # 1. Work out the day of the month of the provided date
  # 2. Get the last day of the month
  # 3. Subtract the number of days in the month, leaving us with
  #    the last day of the previous month
  # 4. Get the first day of the previous month
  # 5. Add back the day of the month capture earlier - potentially coercing
  #    the last day of the month
  def plus(year, week, day, config, :months, -1 = n, options) do
    day_of_month = day_of_month(year, week, day, config)
    {year, week, day} = last_day_of_month(year, week, day, config)
    month_of_year = month_of_year(year, week, day, config)
    month_in_quarter = month_in_quarter(week, config)

    weeks_to_sub =
      slice_weeks(month_in_quarter - 1, abs(n), config) +
        maybe_extra_week_for_long_year(year, month_of_year, config)

    week = week - weeks_to_sub
    {weeks_in_year, _} = weeks_in_year(year - 1, config)
    # IO.puts "  Proposed week of previous month: #{week}"
    {year, week} =
      if week < 1 do
        {year - 1, weeks_in_year - week}
      else
        {year, week}
      end

    {year, week, day} = first_day_of_month(year, week, day, config)
    add_days(year, week, day, day_of_month - 1, config, options)
  end

  # Accounting for long years is complex. So for now adding and
  # subtracting months is done one month at a time. Therefore
  # performance for large additions/subsctractions will be poor.
  def plus(year, week, day, config, :months, months, options) when abs(months) > 1 do
    increment = if months > 0, do: 1, else: -1
    original_day_of_month = day_of_month(year, week, day, config)

    {year, week, day} =
      Enum.reduce(1..abs(months), {year, week, day}, fn _i, {year, week, day} ->
        plus(year, week, day, config, :months, increment, coerce: @default_coercion)
      end)

    # Now reconcile the original date of the month with the
    # previously calculated day of the month.
    proposed_day_of_month = day_of_month(year, week, day, config)
    days_difference = original_day_of_month - proposed_day_of_month
    month = month_of_year(year, week, day, config)

    if days_difference < 0 && original_day_of_month <= days_in_month(year, month, config) do
      add_days(year, month, day, days_difference, config, options)
    else
      {year, week, day}
    end
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

  def add(naive_datetime, :year, step) do
    %{year: year, month: month, day: day} = Cldr.Calendar.plus(naive_datetime, :years, step)
    %NaiveDateTime{naive_datetime | year: year, month: month, day: day}
  end

  def day_of_month(year, week, day, config) do
    first_day = first_day_of_month(year, week, day, config)
    date_diff({year, week, day}, first_day, config) + 1
  end

  def date_diff({y2, w2, d2}, {y1, w1, d1}, config) do
    date_to_iso_days(y2, w2, d2, config) - date_to_iso_days(y1, w1, d1, config)
  end

  def add_days(year, week, day, days, config, options \\ [])

  def add_days(year, week, day, 0, _config, _options) do
    {year, week, day}
  end

  def add_days(year, week, day, days, config, options) do
    days_to_add =
      if Keyword.get(options, :coerce, @default_coercion) do
        month = month_of_year(year, week, day, config)
        min(days_in_month(year, month, config) - 1, days)
      else
        days
      end

    iso_days = date_to_iso_days(year, week, day, config) + days_to_add
    date_from_iso_days(iso_days, config)
  end

  def slice_weeks(from, n, %{weeks_in_month: weeks_in_month}) do
    {_, weeks} = Enum.split(weeks_in_month, from)

    weeks
    |> Enum.take(n)
    |> Enum.sum()
  end

  def first_day_of_month(year, week, day, config) do
    quarters = quarter_of_year(year, week, day, config) - 1
    month_in_quarter = month_in_quarter(week, config) - 1
    week = quarters * @weeks_in_quarter + weeks_from_months(month_in_quarter, config) + 1
    {year, week, 1}
  end

  def last_day_of_month(year, week, day, config) do
    {year, week, day} = first_day_of_month(year, week, day, config)
    month_of_year = month_of_year(year, week, day, config)
    days_in_month = days_in_month(year, month_of_year, config)
    add_days(year, week, day, days_in_month - 1, config)
  end

  def month_in_quarter(week, _config) when week == @weeks_in_long_year do
    @months_in_quarter
  end

  def month_in_quarter(week, config) do
    week_in_quarter = Cldr.Math.amod(week, @weeks_in_quarter)
    month_from_weeks(week_in_quarter, config)
  end

  def weeks_from_months(0, _config) do
    0
  end

  # When months is positive we just sum the first n members of the
  # weeks_in_month list.
  def weeks_from_months(months, %{weeks_in_month: weeks_in_month}) when months > 0 do
    weeks_in_month
    |> Enum.take(months)
    |> Enum.sum()
  end

  # When months is negative
  # TODO May not be correct
  def weeks_from_months(months, %{weeks_in_month: weeks_in_month}) when months < 0 do
    {_, weeks_in_month} = List.pop_at(weeks_in_month, -1)

    weeks_in_month
    |> Enum.take(months)
    |> Enum.sum()
  end

  # For weeks <= 13
  def month_from_weeks(weeks, %Config{weeks_in_month: [m1, m2, m3]})
      when weeks <= @weeks_in_quarter do
    cond do
      weeks <= m1 -> 1
      weeks <= m1 + m2 -> 2
      weeks <= m1 + m2 + m3 -> 3
    end
  end

  def sign(number) when number < 0, do: -1
  def sign(_number), do: +1

  def first_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    {year, _} = Cldr.Calendar.start_end_gregorian_years(year, config)

    %{
      month_of_year: first_month,
      day_of_week: first_day,
      min_days_in_first_week: min_days
    } = config

    iso_days = ISO.date_to_iso_days(year, first_month, min_days)
    day_of_week = Cldr.Calendar.iso_days_to_day_of_week(iso_days)

    # The iso_days calculation is the last possible first day of the first week
    # All starting days are less than or equal to this day
    if first_day > day_of_week do
      iso_days + (first_day - days_in_week() - day_of_week)
    else
      iso_days - (day_of_week - first_day)
    end
  end

  def first_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    last_gregorian_day_of_year(year - 1, config) + 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    first_gregorian_day_of_year(year + 1, config) - 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    {_, year} = Cldr.Calendar.start_end_gregorian_years(year, config)

    %{
      month_of_year: last_month,
      day_of_week: last_day,
      min_days_in_first_week: min_days
    } = config

    days_in_last_month = ISO.days_in_month(year, last_month)
    iso_days = ISO.date_to_iso_days(year, last_month, days_in_last_month - min_days)
    day_of_week = Cldr.Calendar.iso_days_to_day_of_week(iso_days)

    if last_day <= day_of_week do
      iso_days - (day_of_week - last_day) + days_in_week()
    else
      iso_days - (day_of_week - last_day)
    end
  end

  def long_year?(year, %Config{} = config) do
    first_day = first_gregorian_day_of_year(year, config)
    last_day = last_gregorian_day_of_year(year, config)
    days_in_year = last_day - first_day + 1
    div(days_in_year, days_in_week()) == @weeks_in_long_year
  end

  def date_to_iso_days(year, week, day, config) do
    {days, _day_fraction} = naive_datetime_to_iso_days(year, week, day, 0, 0, 0, {0, 6}, config)
    days
  end

  def date_from_iso_days(iso_day_number, config) do
    {year, week, day, _, _, _, _} = naive_datetime_from_iso_days({iso_day_number, {0, 6}}, config)
    {year, week, day}
  end

  def date_to_string(year, week, day) do
    "#{year}-W#{lpad(week)}-#{day}"
  end

  def naive_datetime_from_iso_days({days, day_fraction}, config) do
    {year, _month, _day} = Calendar.ISO.date_from_iso_days(days)
    first_day = first_gregorian_day_of_year(year, config)

    {year, first_day} =
      cond do
        first_day > days ->
          {year - 1, first_gregorian_day_of_year(year - 1, config)}

        days - first_day + 1 > config.calendar.days_in_year(year) ->
          {year + 1, first_gregorian_day_of_year(year + 1, config)}

        true ->
          {year, first_day}
      end

    day_of_year = days - first_day + 1
    week = trunc(Float.ceil(day_of_year / days_in_week()))
    day = day_of_year - (week - 1) * days_in_week()

    {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
    {year, week, day, hour, minute, second, microsecond}
  end

  def naive_datetime_to_iso_days(year, week, day, hour, minute, second, microsecond, config) do
    days = first_gregorian_day_of_year(year, config) + week_to_days(week) + day - 1
    day_fraction = Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)
    {days, day_fraction}
  end

  def datetime_to_string(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond,
        time_zone,
        zone_abbr,
        utc_offset,
        std_offset
      ) do
    date_to_string(year, month, day) <>
      " " <>
      Calendar.ISO.time_to_string(hour, minute, second, microsecond) <>
      Cldr.Calendar.offset_to_string(utc_offset, std_offset, time_zone) <>
      Cldr.Calendar.zone_to_string(utc_offset, std_offset, zone_abbr, time_zone)
  end

  def naive_datetime_to_string(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond
      ) do
    date_to_string(year, month, day) <>
      " " <>
      Calendar.ISO.time_to_string(hour, minute, second, microsecond)
  end

  defp lpad(week) when week < 10 do
    "0#{week}"
  end

  defp lpad(week) do
    week
  end

  defp week_to_days(week) do
    (week - 1) * days_in_week()
  end

  defp maybe_extra_week_for_long_year(year, @months_in_year, config) do
    if long_year?(year, config), do: 1, else: 0
  end

  defp maybe_extra_week_for_long_year(_year, _month, _config) do
    0
  end
end
