defmodule Cldr.Calendar.Behaviour do
  defmacro __using__(opts \\ []) do
    epoch = Keyword.fetch!(opts, :epoch)

    {date, []} = Code.eval_quoted(epoch)
    epoch = Cldr.Calendar.date_to_iso_days(date)

    epoch_day_of_week = Date.day_of_week(date)
    days_in_week = Keyword.get(opts, :days_in_week, 7)
    first_day_of_week = Keyword.get(opts, :first_day_of_week, 1)

    cldr_calendar_type = Keyword.get(opts, :cldr_calendar_type, :gregorian)
    cldr_calendar_base = Keyword.get(opts, :cldr_calendar_base, :month)
    months_in_ordinary_year = Keyword.get(opts, :months_in_ordinary_year, 12)
    months_in_leap_year = Keyword.get(opts, :months_in_leap_year, months_in_ordinary_year)

    quote location: :keep do
      import Cldr.Macros

      @behaviour Calendar
      @behaviour Cldr.Calendar

      @after_compile Cldr.Calendar.Behaviour

      @days_in_week unquote(days_in_week)
      @quarters_in_year 4

      @epoch unquote(epoch)
      @epoch_day_of_week unquote(epoch_day_of_week)
      @first_day_of_week unquote(first_day_of_week)
      @last_day_of_week Cldr.Math.amod(@first_day_of_week + @days_in_week - 1, @days_in_week)

      @months_in_ordinary_year unquote(months_in_ordinary_year)
      @months_in_leap_year unquote(months_in_leap_year)

      def epoch do
        @epoch
      end

      def epoch_day_of_week do
        @epoch_day_of_week
      end

      def first_day_of_week do
        @first_day_of_week
      end

      def last_day_of_week do
        @last_day_of_week
      end

      @doc """
      Defines the CLDR calendar type for this calendar.

      This type is used in support of `Cldr.Calendar.
      localize/3`.

      """
      @impl true
      def cldr_calendar_type do
        unquote(cldr_calendar_type)
      end

      @doc """
      Identifies whether this calendar is month
      or week based.

      """
      @impl true
      def calendar_base do
        unquote(cldr_calendar_base)
      end

      @doc """
      Determines if the `date` given is valid according to
      this calendar.

      """
      @impl true
      def valid_date?(year, month, day) do
        month <= months_in_year(year) && day <= days_in_month(year, month)
      end

      @doc """
      Returns the number of months in a normal year.

      """
      def months_in_ordinary_year do
        @months_in_ordinary_year
      end

      @doc """
      Returns the number of months in a leap year.

      """
      def months_in_leap_year do
        @months_in_leap_year
      end

      @doc """
      Calculates the year and era from the given `year`.

      """

      @era_module Cldr.Calendar.Era.era_module(unquote(cldr_calendar_type))

      @spec year_of_era(Calendar.year()) :: {year :: Calendar.year(), era :: Calendar.era()}

      unless Code.ensure_loaded?(Calendar.ISO) &&
               function_exported?(Calendar.ISO, :year_of_era, 3) do
        @impl true
      end

      def year_of_era(year) do
        iso_days = date_to_iso_days(year, 1, 1)
        @era_module.year_of_era(iso_days, year)
      end

      @doc """
      Calculates the year and era from the given `date`.

      """
      @spec year_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {year :: Calendar.year(), era :: Calendar.era()}

      @impl true
      def year_of_era(year, month, day) do
        iso_days = date_to_iso_days(year, month, day)
        @era_module.year_of_era(iso_days, year)
      end

      @doc """
      Returns the calendar year as displayed
      on rendered calendars.

      """
      @spec calendar_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def calendar_year(year, month, day) do
        year
      end

      @doc """
      Returns the related gregorain year as displayed
      on rendered calendars.

      """
      @spec related_gregorian_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.year()

      @impl true
      def related_gregorian_year(year, month, day) do
        year
      end

      @doc """
      Returns the extended year as displayed
      on rendered calendars.

      """
      @spec extended_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()

      @impl true
      def extended_year(year, month, day) do
        year
      end

      @doc """
      Returns the cyclic year as displayed
      on rendered calendars.

      """
      @spec cyclic_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()

      @impl true
      def cyclic_year(year, month, day) do
        year
      end

      @doc """
      Returns the quarter of the year from the given
      `year`, `month`, and `day`.

      """
      @spec quarter_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Cldr.Calendar.quarter()

      @impl true
      def quarter_of_year(year, month, day) do
        ceil(month / (months_in_year(year) / @quarters_in_year))
      end

      @doc """
      Returns the month of the year from the given
      `year`, `month`, and `day`.

      """
      @spec month_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.month() | {Calendar.month(), Cldr.Calendar.leap_month?()}

      @impl true
      def month_of_year(_year, month, _day) do
        month
      end

      @doc """
      Calculates the week of the year from the given
      `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {:error, :not_defined}

      @impl true
      def week_of_year(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the ISO week of the year from the
      given `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec iso_week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {:error, :not_defined}

      @impl true
      def iso_week_of_year(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the week of the year from the given
      `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec week_of_month(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {pos_integer(), pos_integer()} | {:error, :not_defined}

      @impl true
      def week_of_month(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the day and era from the given
      `year`, `month`, and `day`.

      By default we consider on two eras: before the epoch
      and on-or-after the epoch.

      """
      @spec day_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {day :: Calendar.day(), era :: Calendar.era()}

      @impl true
      def day_of_era(year, month, day) do
        iso_days = date_to_iso_days(year, month, day)
        @era_module.day_of_era(iso_days)
      end

      @doc """
      Calculates the day of the year from the given
      `year`, `month`, and `day`.

      """
      @spec day_of_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.day()

      @impl true
      def day_of_year(year, month, day) do
        first_day = date_to_iso_days(year, 1, 1)
        this_day = date_to_iso_days(year, month, day)
        this_day - first_day + 1
      end

      if Code.ensure_loaded?(Date) && function_exported?(Date, :day_of_week, 2) do
        @impl true

        @spec day_of_week(Calendar.year(), Calendar.month(), Calendar.day(), :default | atom()) ::
                {Calendar.day_of_week(), first_day_of_week :: non_neg_integer(),
                 last_day_of_week :: non_neg_integer()}

        def day_of_week(year, month, day, :default = starting_on) do
          days = date_to_iso_days(year, month, day)
          day_of_week = Cldr.Math.amod(days - 1, @days_in_week)

          {day_of_week, @first_day_of_week, @last_day_of_week}
        end

        defoverridable day_of_week: 4
      else
        @impl true

        @spec day_of_week(Calendar.year(), Calendar.month(), Calendar.day()) :: 1..7
        def day_of_week(year, month, day) do
          day_of_week(year, month, day, :default)
        end

        defoverridable day_of_week: 3
      end

      if Code.ensure_loaded?(Calendar.ISO) && function_exported?(Calendar.ISO, :shift_date, 4) do
        @impl true
        def shift_date(year, month, day, duration) do
          Cldr.Calendar.shift_date(year, month, day, __MODULE__, duration)
        end

        @impl true
        def shift_time(hour, minute, second, microsecond, duration) do
          Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)
        end

        @impl true
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
      Returns the number of periods in a given
      `year`. A period corresponds to a month
      in month-based calendars and a week in
      week-based calendars.

      """
      @impl true

      def periods_in_year(year) do
        months_in_year(year)
      end

      @doc """
      Returns the number of months in a
      given `year`.

      """
      @impl true

      def months_in_year(year) do
        if leap_year?(year), do: @months_in_leap_year, else: @months_in_ordinary_year
      end

      @doc """
      Returns the number of weeks in a
      given `year`.

      """
      @impl true

      def weeks_in_year(_year) do
        {:error, :not_defined}
      end

      @doc """
      Returns the number days in a given year.

      The year is the number of years since the
      epoch.

      """
      @impl true

      def days_in_year(year) do
        this_year = date_to_iso_days(year, 1, 1)
        next_year = date_to_iso_days(year + 1, 1, 1)
        next_year - this_year + 1
      end

      @doc """
      Returns how many days there are in the given year
      and month.

      """
      @spec days_in_month(Calendar.year(), Calendar.month()) :: Calendar.month()
      @impl true

      def days_in_month(year, month) do
        start_of_this_month =
          date_to_iso_days(year, month, 1)

        start_of_next_month =
          if month == months_in_year(year) do
            date_to_iso_days(year + 1, 1, 1)
          else
            date_to_iso_days(year, month + 1, 1)
          end

        start_of_next_month - start_of_this_month
      end

      @doc """
      Returns how many days there are in the given month.

      Must be implemented in derived calendars because
      we cannot know what the calendar format is.

      """
      @spec days_in_month(Calendar.month()) ::
              Calendar.month() | {:ambiguous, Range.t() | [pos_integer()]} | {:error, :undefined}
      @impl true

      def days_in_month(month) do
        {:error, :undefined}
      end

      @doc """
      Returns the number days in a a week.

      """
      def days_in_week do
        @days_in_week
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given year.

      """
      @impl true

      def year(year) do
        last_month = months_in_year(year)
        days_in_last_month = days_in_month(year, last_month)

        with {:ok, start_date} <- Date.new(year, 1, 1, __MODULE__),
             {:ok, end_date} <- Date.new(year, last_month, days_in_last_month, __MODULE__) do
          Date.range(start_date, end_date)
        end
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given quarter of a year.

      """
      @impl true

      def quarter(_year, _quarter) do
        {:error, :not_defined}
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given month of a year.

      """
      @impl true

      def month(year, month) do
        starting_day = 1
        ending_day = days_in_month(year, month)

        with {:ok, start_date} <- Date.new(year, month, starting_day, __MODULE__),
             {:ok, end_date} <- Date.new(year, month, ending_day, __MODULE__) do
          Date.range(start_date, end_date)
        end
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given week of a year.

      """
      @impl true

      def week(_year, _week) do
        {:error, :not_defined}
      end

      @doc """
      Adds an `increment` number of `date_part`s
      to a `year-month-day`.

      `date_part` can be `:months` only.

      """
      @impl true

      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :months, months, options) do
        months_in_year = months_in_year(year)
        {year_increment, new_month} = Cldr.Math.div_amod(month + months, months_in_year)
        new_year = year + year_increment

        new_day =
          if Keyword.get(options, :coerce, false) do
            max_new_day = days_in_month(new_year, new_month)
            min(day, max_new_day)
          else
            day
          end

        {new_year, new_month, new_day}
      end

      @doc """
      Returns the `t:Calendar.iso_days` format of
      the specified date.

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

      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        {date_to_iso_days(year, month, day),
         time_to_day_fraction(hour, minute, second, microsecond)}
      end

      @doc """
      Converts the `t:Calendar.iso_days` format to the
      datetime format specified by this calendar.

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
        {year, month, day} = date_from_iso_days(days)
        {hour, minute, second, microsecond} = time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc false
      calendar_impl()

      def parse_date(string) do
        Cldr.Calendar.Parse.parse_date(string, __MODULE__)
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
      @impl Calendar
      defdelegate parse_time(string), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate date_to_string(year, month, day), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate datetime_to_string(
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
                  ),
                  to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate naive_datetime_to_string(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                    microsecond
                  ),
                  to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO

      if Code.ensure_loaded?(Calendar.ISO) &&
           function_exported?(Calendar.ISO, :iso_days_to_beginning_of_day, 1) do
        @doc false
        @impl true
        defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

        @doc false
        @impl true
        defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO
      end

      defoverridable valid_date?: 3
      defoverridable valid_time?: 4
      defoverridable naive_datetime_to_string: 7
      defoverridable date_to_string: 3
      defoverridable time_to_day_fraction: 4
      defoverridable time_from_day_fraction: 1
      defoverridable day_rollover_relative_to_midnight_utc: 0
      defoverridable parse_time: 1
      defoverridable parse_naive_datetime: 1
      defoverridable parse_utc_datetime: 1
      defoverridable parse_date: 1
      defoverridable naive_datetime_from_iso_days: 1
      defoverridable naive_datetime_to_iso_days: 7

      defoverridable year_of_era: 1
      defoverridable quarter_of_year: 3
      defoverridable month_of_year: 3
      defoverridable week_of_year: 3
      defoverridable iso_week_of_year: 3
      defoverridable week_of_month: 3
      defoverridable day_of_era: 3
      defoverridable day_of_year: 3

      defoverridable periods_in_year: 1
      defoverridable months_in_year: 1
      defoverridable weeks_in_year: 1
      defoverridable days_in_year: 1
      defoverridable days_in_month: 2
      defoverridable days_in_month: 1
      defoverridable days_in_week: 0

      defoverridable year: 1
      defoverridable quarter: 2
      defoverridable month: 2
      defoverridable week: 2
      defoverridable plus: 5
      defoverridable plus: 6

      defoverridable epoch: 0
      defoverridable cldr_calendar_type: 0
      defoverridable calendar_base: 0

      defoverridable calendar_year: 3
      defoverridable extended_year: 3
      defoverridable related_gregorian_year: 3
      defoverridable cyclic_year: 3
    end
  end

  def __after_compile__(env, _bytecode) do
    Cldr.Calendar.Era.define_era_module(env.module)
  end
end
