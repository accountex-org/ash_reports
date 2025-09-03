defmodule Cldr.Calendar.Era do
  @moduledoc """
  Encapsulates the era information for
  known CLDR calendars.

  The [era data in CLDR](https://github.com/unicode-org/cldr/blob/master/common/supplemental/supplementalData.xml)
  is presented in different calendars at different times. The current
  best understanding is:

  ### Japanese Calendar

  * From Taisho (1912), the date is Gregorian year,
    month and day.

  * For Tenshō (Momoyama period) to Meji era (1868)
    inclusive its Gregorian year but lunar month and day.

  * For earlier eras it is Julian year with lunar month and
    day (but the Julian and Gregorian years coincide; there are
    no era dates where the Gregorian year would be different
    to the Julian year).

  ### Other Calendars

  * For Chinese and Korean (dangi) the era dates are
    Gregorian year with lunar month and lunar day

  * For Coptic, Ethiopic and Islamic calendars the eras are
    Julian dates (Julian day, month and year).

  * Persian era is Julian year with persian month and day.

  * Gregorian is, well, Gregorian date.

  """

  # Just after a calendar is defined this function
  # is called to create a module that provides a
  # lookup function returning the appropriate era
  # number for a given date in a given calendar.
  #
  # If the calendar does not have a known CLDR
  # calendar name associated with it then no
  # module is produced and no error is returned.

  @doc false
  def define_era_module(calendar_module) do
    if function_exported?(calendar_module, :cldr_calendar_type, 0) &&
         !Code.ensure_loaded?(era_module(calendar_module.cldr_calendar_type())) do
      cldr_calendar = calendar_module.cldr_calendar_type()
      era_module = era_module(cldr_calendar)

      cldr_calendar
      |> eras_for_calendar()
      |> eras_to_iso_days(cldr_calendar, calendar_module)
      |> define_era_module(calendar_module, era_module)
    else
      :no_op
    end
  end

  # Returns a list of eras with the most
  # recent era first (we want this sort
  # order so that when we generate function
  # clauses, most recent dates match first and
  # those are the dates most likely to be used).

  @doc false
  def eras_for_calendar(calendar) do
    Cldr.Config.calendars()
    |> Map.fetch!(calendar)
    |> Map.fetch!(:eras)
    |> Enum.reverse()
  end

  @eras_in_gregorian_year [
    :chinese,
    :dangi,
    :persian,
    :gregorian
  ]

  @eras_in_julian_calendar [
    :coptic,
    :ethiopic,
    :islamic,
    :islamic_civil,
    :islamic_rgsa,
    :islamic_tbla,
    :islamic_umalqura
  ]

  # Four of the era dates below are invalid in the CLDR data
  # as of April 10th, 2023 and CLDR 4r3.

  @doc false
  def eras_to_iso_days(eras, :japanese, _calendar) do
    Enum.map(eras, fn
      [era, %{start: [1504 = year, 2 = month, 30]}] ->
        [era, start: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, 29), year: year]

      [era, %{start: [1624 = year, 2 = month, 30]}] ->
        [era, start: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, 28), year: year]

      [era, %{start: [1501 = year, 2 = month, 29]}] ->
        [era, start: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, 28), year: year]

      [era, %{start: [1278 = year, 2 = month, 29]}] ->
        [era, start: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, 28), year: year]

      [era, %{start: [year, month, day]}] ->
        [era, start: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, day), year: year]

      [era, %{end: [year, month, day]}] ->
        [era, end: Cldr.Calendar.Gregorian.date_to_iso_days(year, month, day), year: year]
    end)
  end

  def eras_to_iso_days(eras, cldr_calendar, calendar)
      when cldr_calendar in @eras_in_gregorian_year do
    Enum.map(eras, fn
      [era, %{start: [year, month, day]}] ->
        [era, start: calendar.date_to_iso_days(year, month, day), year: year]

      [era, %{end: [year, month, day]}] ->
        [era, end: calendar.date_to_iso_days(year, month, day), year: year]
    end)
  end

  def eras_to_iso_days(eras, cldr_calendar, _calendar)
      when cldr_calendar in @eras_in_julian_calendar do
    Enum.map(eras, fn
      [era, %{start: [year, month, day]}] ->
        [era, start: Cldr.Calendar.Julian.date_to_iso_days(year, month, day), year: year]

      [era, %{end: [year, month, day]}] ->
        [era, end: Cldr.Calendar.Julian.date_to_iso_days(year, month, day), year: year]
    end)
  end

  defp define_era_module(eras, calendar, module) do
    module_body = [moduledoc(module), default(calendar) | function_body(eras)]
    Module.create(module, module_body, Macro.Env.location(__ENV__))
  end

  defp moduledoc(module) do
    quote do
      @moduledoc """
      Implements a `year_of_era/{1, 2}` function to return
      the year of era and the era number for the
      `#{inspect(unquote(module))}` calendar.

      This module is generated at compile time from
      CLDR era data.

      """

      @doc false
      @spec year_of_era(integer(), Calendar.year()) :: {Calendar.year(), Calendar.era()}
    end
  end

  defp default(calendar) do
    quote do
      @doc """
      Returns the year of era and the era number
      for a given date in `iso_days`.

      """
      @spec year_of_era(integer()) :: {Calendar.year(), Calendar.era()}

      def year_of_era(iso_days) do
        {year, _month, _day} = unquote(calendar).date_from_iso_days(iso_days)
        year_of_era(iso_days, year)
      end

      @doc """
      Returns the day of era and the era number
      for a given date in `iso_days`.

      """
      @spec day_of_era(integer()) :: {Calendar.day(), Calendar.era()}

      def day_of_era(iso_days)

      @doc false
      def era(iso_days)
    end
  end

  defp function_body(eras) do
    for [era, {position, date}, {:year, era_year}] <- eras do
      case position do
        :start ->
          quote do
            def year_of_era(iso_days, year)
                when iso_days >= unquote(date) and year < unquote(era_year) do
              {1, unquote(era)}
            end

            def year_of_era(iso_days, year) when iso_days >= unquote(date) do
              {year - unquote(era_year) + 1, unquote(era)}
            end

            def day_of_era(iso_days) when iso_days >= unquote(date) do
              {iso_days - unquote(date) + 1, unquote(era)}
            end

            def era(iso_days) when iso_days >= unquote(date) do
              {unquote(date), nil, unquote(era)}
            end
          end

        :end ->
          quote do
            def year_of_era(iso_days, year) when iso_days <= unquote(date) do
              {year - unquote(era_year) + 1, unquote(era)}
            end

            def day_of_era(iso_days) when iso_days <= unquote(date) do
              {iso_days + 1, unquote(era)}
            end

            def era(iso_days) when iso_days >= unquote(date) do
              {nil, unquote(date), unquote(era)}
            end
          end
      end
    end
  end

  @doc """
  Return the era module for a given
  cldr calendar type.

  """
  @era_module_base Cldr.Calendar.Era

  def era_module(cldr_calendar) do
    module = to_string(cldr_calendar) |> String.capitalize()
    Module.concat(@era_module_base, module)
  end
end
