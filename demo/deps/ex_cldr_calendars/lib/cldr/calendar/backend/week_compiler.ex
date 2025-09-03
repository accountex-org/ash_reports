defmodule Cldr.Calendar.Compiler.Week do
  @moduledoc false

  defmacro __before_compile__(env) do
    config =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Cldr.Calendar.Config.extract_options()
      |> Cldr.Calendar.Config.validate_config!(:week)

    Module.put_attribute(env.module, :calendar_config, config)

    quote location: :keep do
      @behaviour Calendar
      @behaviour Cldr.Calendar

      # @type year :: -9999..9999
      # @type month :: 1..12
      # @type week :: 1..53
      # @type day :: 1..7

      import Cldr.Macros

      import Cldr.Calendar,
        only: [
          missing_date_error: 4,
          missing_year_month_error: 3,
          missing_month_error: 2,
          missing_year_error: 2
        ]

      alias Cldr.Calendar.Base.Week

      def __config__ do
        @calendar_config
      end

      @doc """
      Identifies that the calendar is week based.
      """
      @impl true
      def calendar_base do
        :week
      end

      @doc """
      Defines the CLDR calendar type for this calendar.

      This type is used in support of `Cldr.Calendar.localize/3`.
      Currently only `:gregorian` is supported.

      """
      @impl true
      def cldr_calendar_type do
        :gregorian
      end

      @doc """
      Determines if the date given is valid according to the this calendar.

      """
      @impl true
      def valid_date?(year, week, day) do
        Week.valid_date?(year, week, day, __config__())
      end

      @doc """
      Calculates the year and era from the given `year`.
      The ISO calendar has two eras: the current era which
      starts in year 1 and is defined as era "1". And a
      second era for those years less than 1 defined as
      era "0".

      """
      @spec year_of_era(Cldr.Calendar.year()) ::
              {year :: Calendar.year(), era :: Cldr.Calendar.era()}

      unless Code.ensure_loaded?(Calendar.ISO) &&
               function_exported?(Calendar.ISO, :year_of_era, 3) do
        @impl true
      end

      def year_of_era(year) do
        Week.year_of_era(year, __config__())
      end

      @doc """
      Calculates the year and era from the given `year`,
      `month` and `day`.

      The ISO calendar has two eras: the current era which
      starts in year 1 and is defined as era "1". And a
      second era for those years less than 1 defined as
      era "0".

      """
      @spec year_of_era(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              {year :: Calendar.year(), era :: Cldr.Calendar.era()}
              | {:error, {module(), String.t()}}

      @impl true

      def year_of_era(year, _week, _day) do
        Week.year_of_era(year, __config__())
      end

      @doc """
      Returns the calendar year as displayed
      on rendered calendars.

      """
      @spec calendar_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              year :: Calendar.year() | {:error, {module(), String.t()}}

      @impl true
      def calendar_year(year, _week, _day) when is_integer(year) do
        year
      end

      def calendar_year(year, _week, _day) do
        {:error, missing_year_error("calendar_year", year)}
      end

      @doc """
      Returns the related gregorian year as displayed
      on rendered calendars.

      """
      @spec related_gregorian_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              year :: Calendar.year() | {:error, {module(), String.t()}}

      @impl true
      def related_gregorian_year(year, _week, _day) when is_integer(year) do
        year
      end

      def related_gregorian_year(year, _week, _day) do
        {:error, missing_year_error("calendar_year", year)}
      end

      @doc """
      Returns the extended year as displayed
      on rendered calendars.

      """
      @spec extended_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              year :: Calendar.year() | {:error, {module(), String.t()}}

      @impl true
      def extended_year(year, week, day) when is_integer(year) do
        year
      end

      def extended_year(year, _week, _day) do
        {:error, missing_year_error("extended_year", year)}
      end

      @doc """
      Returns the cyclic year as displayed
      on rendered calendars.

      """
      @spec cyclic_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              year :: Calendar.year() | {:error, {module(), String.t()}}

      @impl true
      def cyclic_year(year, _week, _day) when is_integer(year) do
        year
      end

      def cyclic_year(year, _week, _day) do
        {:error, missing_year_error("cyclic_year", year)}
      end

      @doc """
      Calculates the quarter of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 4.

      """
      @spec quarter_of_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              quarter :: Cldr.Calendar.quarter() | {:error, {module(), String.t()}}

      @impl true
      def quarter_of_year(year, week, day) do
        Week.quarter_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the month of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 12.

      """
      @spec month_of_year(
              year :: Cldr.Calendar.year(),
              week :: Cldr.Calendar.week(),
              day :: Cldr.Calendar.day()
            ) ::
              month :: Calendar.month() | {:error, {module(), String.t()}}

      @impl true
      def month_of_year(year, week, day) do
        Week.month_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the week of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 53.

      """
      @spec week_of_year(Cldr.Calendar.year(), Cldr.Calendar.month(), Cldr.Calendar.day()) ::
              {year :: Calendar.year(), week :: Cldr.Calendar.week()}
              | {:error, {module(), String.t()}}

      @impl true
      def week_of_year(year, week, day) do
        Week.week_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the ISO week of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 53.

      """
      @spec iso_week_of_year(Cldr.Calendar.year(), Cldr.Calendar.month(), Cldr.Calendar.day()) ::
              {year :: Calendar.year(), week :: Cldr.Calendar.week()}
              | {:error, {module(), String.t()}}

      @impl true
      def iso_week_of_year(year, week, day) do
        Week.iso_week_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the week of the month from the given `year`, `month`, and `day`.
      It is an integer from 1 to 5.

      """
      @spec week_of_month(Cldr.Calendar.year(), Cldr.Calendar.week(), Calendar.day()) ::
              {month :: Calendar.month(), week :: Cldr.Calendar.week()}
              | {:error, {module(), String.t()}}

      @impl true
      def week_of_month(year, week, day) do
        Week.week_of_month(year, week, day, __config__())
      end

      @doc """
      Calculates the day and era from the given `year`, `month`, and `day`.

      """
      @spec day_of_era(Cldr.Calendar.year(), Cldr.Calendar.month(), Cldr.Calendar.day()) ::
              {day :: Cldr.Calendar.day(), era :: Cldr.Calendar.era()}
              | {:error, {module(), String.t()}}

      @impl true
      def day_of_era(year, week, day) do
        Week.day_of_era(year, week, day, __config__())
      end

      @doc """
      Calculates the day of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 366.

      """
      @spec day_of_year(Cldr.Calendar.year(), Cldr.Calendar.month(), Cldr.Calendar.day()) ::
              day :: Calendar.day() | {:error, {module(), String.t()}}

      @impl true
      def day_of_year(year, week, day) do
        Week.day_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the day of the week from the given `year`, `month`, and `day`.
      It is an integer from 1 to 7, where 1 is Monday and 7 is Sunday.

      """
      @spec day_of_week(
              year :: Cldr.Calendar.year(),
              month :: Cldr.Calendar.month(),
              Cldr.Calendar.day(),
              :default | atom()
            ) ::
              {day_of_week :: Calendar.day_of_week(),
               first_day_of_week ::
                 Calendar.day_of_week(), last_day_of_week :: Calendar.day_of_week()}
              | {:error, {module(), String.t()}}

      @impl true
      def day_of_week(year, month, day, :default) do
        %{day_of_week: first_day} = __config__()
        last_day = Cldr.Math.amod(first_day + days_in_week() - 1, days_in_week())
        day = Week.day_of_week(year, month, day, __config__())
        {day, first_day, last_day}
      end

      @doc """
      Calculates the number of period in a given `year`. A period
      corresponds to a month in month-based calendars and
      a week in week-based calendars..

      """
      @spec periods_in_year(year :: Cldr.Calendar.year()) :: Calendar.week() | :error
      @impl true
      def periods_in_year(year) do
        {weeks_in_year, _} = weeks_in_year(year)
        weeks_in_year
      end

      @doc """
      Returns the number weeks in a given year.

      ### Arguments

      * `year` is any `t:Calendar.year/0`

      ### Returns

      * `{weeks_in_year, days_in_last_week}`

      ### Example

          iex> Cldr.Calendar.ISOWeek.weeks_in_year 2020
          {53, 7}

          iex> Cldr.Calendar.ISOWeek.weeks_in_year 2021
          {52, 7

      """
      @spec weeks_in_year(year :: Cldr.Calendar.year()) ::
              {weeks :: Calendar.week(), days_in_last_week :: Calendar.day()}
              | {:error, {module(), String.t()}}

      @impl true
      def weeks_in_year(year) do
        Week.weeks_in_year(year, __config__())
      end

      @doc """
      Returns the number days in a given year.

      """
      @spec days_in_year(year :: Cldr.Calendar.year()) ::
              days :: Calendar.day() | {:error, {module(), String.t()}}

      @impl true
      def days_in_year(year) do
        Week.days_in_year(year, __config__())
      end

      @doc """
      Returns how many days there are in the given year-month.

      """
      @spec days_in_month(year :: Cldr.Calendar.year(), month :: Cldr.Calendar.month()) ::
              days ::
              Calendar.day()
              | {:error, {module(), String.t()}}
              | {:ambiguous, Range.t()}
              | {:ambiguous, [integer(), ...]}

      @impl true
      def days_in_month(year, month) do
        Week.days_in_month(year, month, __config__())
      end

      @doc """
      Returns how many days there are in the given month.

      If the days in month cannot be determined without
      knowning the year and error tuple is returned.

      """
      @spec days_in_month(month :: Cldr.Calendar.month()) ::
              days ::
              Calendar.day()
              | {:error, {module(), String.t()}}
              | {:ambiguous, Range.t()}
              | {:ambiguous, [integer(), ...]}

      @impl true
      def days_in_month(month) do
        Week.days_in_month(month, __config__())
      end

      @doc """
      Returns the number days in a a week.

      """
      def days_in_week do
        Week.days_in_week()
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given year.

      """
      @impl true
      def year(year) do
        Week.year(year, __config__())
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given quarter of a year.

      """
      @impl true
      def quarter(year, quarter) do
        Week.quarter(year, quarter, __config__())
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given month of a year.

      """
      @impl true
      def month(year, month) do
        Week.month(year, month, __config__())
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given week of a year.

      """
      @impl true
      def week(year, week) do
        Week.week(year, week, __config__())
      end

      @doc """
      Adds an `increment` number of `date_part`s
      to a `year-month-day`.

      `date_part` can be `:years`, `:quarters`,
      `:months` or `days`.

      """
      @impl true
      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :years, quarters, options) do
        Week.plus(year, month, day, __config__(), :years, quarters, options)
      end

      def plus(year, week, day, :quarters, quarters, options) do
        Week.plus(year, week, day, __config__(), :quarters, quarters, options)
      end

      def plus(year, week, day, :months, months, options) do
        Week.plus(year, week, day, __config__(), :months, months, options)
      end

      def plus(year, month, day, :weeks, weeks, options) do
        Week.plus(year, month, day, __config__(), :weeks, weeks, options)
      end

      def plus(year, week, day, :days, days, options) do
        Week.plus(year, week, day, __config__(), :days, days, options)
      end

      @doc """
      Adds a :year, :month, :day or time increments

      These functions support CalendarInterval

      """
      def add(year, month, day, hour, minute, second, microsecond, :year, step) do
        {year, month, day} = plus(year, month, day, :years, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      def add(year, month, day, hour, minute, second, microsecond, :quarter, step) do
        {year, month, day} = plus(year, month, day, :quarters, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      def add(year, month, day, hour, minute, second, microsecond, :month, step) do
        {year, month, day} = plus(year, month, day, :months, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc """
      Returns if the given year is a leap year.

      """
      @spec leap_year?(Cldr.Calendar.year()) :: boolean()
      @impl true
      def leap_year?(year) do
        Week.long_year?(year, __config__())
      end

      if Code.ensure_loaded?(Calendar.ISO) && function_exported?(Calendar.ISO, :shift_date, 4) do
        @doc """
        Shifts a date by given duration.

        """
        @spec shift_date(Calendar.year(), Calendar.month(), Calendar.day(), Duration.t()) ::
                {Calendar.year(), Calendar.month(), Calendar.day()}

        @impl Calendar
        def shift_date(year, month, day, duration) do
          Cldr.Calendar.shift_date(year, month, day, __MODULE__, duration)
        end

        @doc """
        Shifts a time by given duration.

        """
        @spec shift_time(
                Calendar.hour(),
                Calendar.minute(),
                Calendar.second(),
                Calendar.microsecond(),
                Duration.t()
              ) ::
                {Calendar.hour(), Calendar.minute(), Calendar.second(), Calendar.microsecond()}

        @impl Calendar
        def shift_time(hour, minute, second, microsecond, duration) do
          Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)
        end

        @doc """
        Shifts a naive date time by given duration.

        """
        @spec shift_naive_datetime(
                Calendar.year(),
                Calendar.month(),
                Calendar.day(),
                Calendar.hour(),
                Calendar.minute(),
                Calendar.second(),
                Calendar.microsecond(),
                Duration.t()
              ) ::
                {
                  Calendar.year(),
                  Calendar.month(),
                  Calendar.day(),
                  Calendar.hour(),
                  Calendar.minute(),
                  Calendar.second(),
                  Calendar.microsecond()
                }

        @impl Calendar
        def shift_naive_datetime(year, month, day, hour, minute, second, microsecond, duration) do
          Cldr.Calendar.shift_naive_datetime(
            year,
            month,
            day,
            hour,
            minute,
            second,
            microsecond,
            __MODULE__,
            duration
          )
        end
      end

      @doc """
      Returns the number of days since the calendar
      epoch for a given `year-month-day`

      """
      def date_to_iso_days(year, week, day) do
        Week.date_to_iso_days(year, week, day, __config__())
      end

      @doc """
      Returns `{year, month, day}` calculated from
      the number of `iso_days`.

      """
      def date_from_iso_days(iso_days) do
        Week.date_from_iso_days(iso_days, __config__())
      end

      @doc """
      Returns the number of `iso_days` that is
      the first day of the given
      year for this calendar.

      """
      def first_gregorian_day_of_year(year) do
        Week.first_gregorian_day_of_year(year, __config__())
      end

      @doc """
      Returns the number of `iso_days` that is
      the last day of the given
      year for this calendar.

      """
      def last_gregorian_day_of_year(year) do
        Week.last_gregorian_day_of_year(year, __config__())
      end

      @doc """
      Returns the `t:Calendar.iso_days/0` format of the specified date.

      """
      @impl true
      @spec naive_datetime_to_iso_days(
              Calendar.year(),
              Calendar.month(),
              Calendar.day(),
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond()
            ) :: Calendar.iso_days()

      def naive_datetime_to_iso_days(year, week, day, hour, minute, second, microsecond) do
        Week.naive_datetime_to_iso_days(
          year,
          week,
          day,
          hour,
          minute,
          second,
          microsecond,
          __config__()
        )
      end

      @doc """
      Converts the `t:Calendar.iso_days/0` format to the datetime format specified by this calendar.

      """
      @spec naive_datetime_from_iso_days(Calendar.iso_days()) :: {
              Calendar.year(),
              Calendar.month(),
              Calendar.day(),
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond()
            }
      @impl true
      def naive_datetime_from_iso_days({days, day_fraction}) do
        Week.naive_datetime_from_iso_days({days, day_fraction}, __config__())
      end

      @doc false
      @impl true
      def date_to_string(year, month, day) do
        Week.date_to_string(year, month, day)
      end

      @doc false
      @impl true
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
        Week.datetime_to_string(
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
        )
      end

      @doc false
      @impl true
      def naive_datetime_to_string(year, month, day, hour, minute, second, microsecond) do
        Week.naive_datetime_to_string(year, month, day, hour, minute, second, microsecond)
      end

      @doc false
      calendar_impl()

      def parse_date(string) do
        Cldr.Calendar.Parse.parse_week_date(string, __MODULE__)
      end

      @doc false
      calendar_impl()

      def parse_utc_datetime(string) do
        Cldr.Calendar.Parse.parse_utc_datetime(string, __MODULE__)
      end

      @doc false
      calendar_impl()

      def parse_naive_datetime(string) do
        Cldr.Calendar.Parse.parse_naive_datetime(string, __MODULE__)
      end

      @doc false
      defdelegate parse_time(string), to: Calendar.ISO

      if Code.ensure_loaded?(Calendar.ISO) &&
           function_exported?(Calendar.ISO, :iso_days_to_beginning_of_day, 1) do
        @doc false
        defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

        @doc false
        defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO
      end

      @doc false
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      defdelegate months_in_year(year), to: Calendar.ISO

      @doc false
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO
    end
  end
end
