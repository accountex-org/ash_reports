defmodule Cldr.Calendar.Interval do
  @moduledoc """
  Implements functions to return intervals and compare
  date intervals.

  In particular it provides functions which return an
  interval (as a `Date.Range.t`) for years, quarters,
  months, weeks and days.

  In general, the intervals created with the packaage
  [calendar_interval](https://hex.pm/packages/calendar_interval)
  are to be preferred since they can used over different
  time precisions whereas the functions in this module are
  all intervals of a day. In order to be used with `ex_cldr_calendars`,
  version "~> 0.2" of [calendar_interval](https://hex.pm/packages/calendar_interval)
  is required.

  Note however that as of release `0.2`, [calendar_interval](https://hex.pm/packages/calendar_interval) does
  not support intervals of `quarters` or `weeks`.

  """

  @doc """
  Returns a `Date.Range.t` that represents
  the `year`.

  The range is enumerable.

  ## Arguments

  * `year` is any `year` for `calendar`

  * `calendar` is any module that implements
    the `Calendar` and `Cldr.Calendar`
    behaviours. The default is `Cldr.Calendar.Gregorian`.

  ## Returns

  * A `Date.Range.t()` representing the
    the enumerable days in the `year`

  ## Examples

      iex> Cldr.Calendar.Interval.year 2019, Cldr.Calendar.Fiscal.UK
      Date.range(~D[2019-01-01 Cldr.Calendar.Fiscal.UK], ~D[2019-12-31 Cldr.Calendar.Fiscal.UK])

      iex> Cldr.Calendar.Interval.year 2019, Cldr.Calendar.NRF
      Date.range(~D[2019-W01-1 Cldr.Calendar.NRF], ~D[2019-W52-7 Cldr.Calendar.NRF])

  """
  @spec year(Calendar.year(), Cldr.Calendar.calendar()) :: Date.Range.t()
  @spec year(Date.t()) :: Date.Range.t()

  def year(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Cldr.Calendar.Gregorian}
    |> year
    |> coerce_iso_calendar
  end

  def year(%{year: _, month: _, day: _} = date) do
    year(date.year, date.calendar)
  end

  def year(year, calendar \\ Cldr.Calendar.Gregorian) do
    calendar.year(year)
  end

  @doc """
  Returns a `Date.Range.t` that represents
  the `quarter`.

  The range is enumerable.

  ## Arguments

  * `year` is any `year` for `calendar`

  * `quarter` is any `quarter` in the
  `  year` for `calendar`

  * `calendar` is any module that implements
    the `Calendar` and `Cldr.Calendar`
    behaviours. The default is `Cldr.Calendar.Gregorian`.

  ## Returns

  * A `Date.Range.t()` representing the
    the enumerable days in the `quarter`

  ## Examples

      iex> Cldr.Calendar.Interval.quarter 2019, 2, Cldr.Calendar.Fiscal.UK
      Date.range(~D[2019-04-01 Cldr.Calendar.Fiscal.UK], ~D[2019-06-30 Cldr.Calendar.Fiscal.UK])

      iex> Cldr.Calendar.Interval.quarter 2019, 2, Cldr.Calendar.ISOWeek
      Date.range(~D[2019-W14-1 Cldr.Calendar.ISOWeek], ~D[2019-W26-7 Cldr.Calendar.ISOWeek])

  """
  @spec quarter(Calendar.year(), Cldr.Calendar.quarter(), Cldr.Calendar.calendar()) ::
          Date.Range.t()
  @spec quarter(Date.t()) :: Date.Range.t()

  def quarter(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Cldr.Calendar.Gregorian}
    |> quarter
    |> coerce_iso_calendar
  end

  def quarter(date) do
    quarter = Cldr.Calendar.quarter_of_year(date)
    quarter(date.year, quarter, date.calendar)
  end

  def quarter(year, quarter, calendar \\ Cldr.Calendar.Gregorian) do
    calendar.quarter(year, quarter)
  end

  @doc """
  Returns a `Date.Range.t` that represents
  the `year`.

  The range is enumerable.

  ## Arguments

  * `year` is any `year` for `calendar`

  * `month` is any `month` in the `year`
    for `calendar`

  * `calendar` is any module that implements
    the `Calendar` and `Cldr.Calendar`
    behaviours. The default is `Cldr.Calendar.Gregorian`.

  ## Returns

  * A `Date.Range.t()` representing the
    the enumerable days in the `month`

  ## Examples

      iex> Cldr.Calendar.Interval.month 2019, 3, Cldr.Calendar.Fiscal.UK
      Date.range(~D[2019-03-01 Cldr.Calendar.Fiscal.UK], ~D[2019-03-30 Cldr.Calendar.Fiscal.UK])

      iex> Cldr.Calendar.Interval.month 2019, 3, Cldr.Calendar.Fiscal.US
      Date.range(~D[2019-03-01 Cldr.Calendar.Fiscal.US], ~D[2019-03-31 Cldr.Calendar.Fiscal.US])

  """
  @spec month(Calendar.year(), Calendar.month(), Cldr.Calendar.calendar()) :: Date.Range.t()
  @spec month(Date.t()) :: Date.Range.t()

  def month(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Cldr.Calendar.Gregorian}
    |> month
    |> coerce_iso_calendar
  end

  def month(date) do
    month = Cldr.Calendar.month_of_year(date)
    month(date.year, month, date.calendar)
  end

  def month(year, month, calendar \\ Cldr.Calendar.Gregorian) do
    calendar.month(year, month)
  end

  @doc """
  Returns a `Date.Range.t` that represents
  the `year`.

  The range is enumerable.

  ## Arguments

  * `year` is any `year` for `calendar`

  * `week` is any `week` in the `year`
    for `calendar`

  * `calendar` is any module that implements
    the `Calendar` and `Cldr.Calendar`
    behaviours. The default is `Cldr.Calendar.Gregorian`.

  ## Returns

  * A `Date.Range.t()` representing the
    the enumerable days in the `week` or

  * `{:error, :not_defined}` if the calendar
    does not support the concept of weeks

  ## Examples

      iex> Cldr.Calendar.Interval.week 2019, 52, Cldr.Calendar.Fiscal.US
      Date.range(~D[2019-12-22 Cldr.Calendar.Fiscal.US], ~D[2019-12-28 Cldr.Calendar.Fiscal.US])

      iex> Cldr.Calendar.Interval.week 2019, 52, Cldr.Calendar.NRF
      Date.range(~D[2019-W52-1 Cldr.Calendar.NRF], ~D[2019-W52-7 Cldr.Calendar.NRF])

      iex> Cldr.Calendar.Interval.week 2019, 52, Cldr.Calendar.ISOWeek
      Date.range(~D[2019-W52-1 Cldr.Calendar.ISOWeek], ~D[2019-W52-7 Cldr.Calendar.ISOWeek])

      iex> Cldr.Calendar.Interval.week 2019, 52, Cldr.Calendar.Julian
      {:error, :not_defined}

  """
  @spec week(Calendar.year(), Cldr.Calendar.week(), Cldr.Calendar.calendar()) :: Date.Range.t()
  @spec week(Date.t()) :: Date.Range.t()

  def week(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Cldr.Calendar.Gregorian}
    |> week
    |> coerce_iso_calendar
  end

  def week(date) do
    {year, week} = Cldr.Calendar.week_of_year(date)
    week(year, week, date.calendar)
  end

  def week(year, week, calendar \\ Cldr.Calendar.Gregorian) do
    calendar.week(year, week)
  end

  @doc """
  Returns a `Date.Range.t` that represents
  the `day`.

  The range is enumerable.

  ## Arguments

  * `year` is any `year` for `calendar`

  * `day` is any `day` in the `year`
    for `calendar`

  * `calendar` is any module that implements
    the `Calendar` and `Cldr.Calendar`
    behaviours. The default is `Cldr.Calendar.Gregorian`.

  ## Returns

  * A `Date.Range.t()` representing the
    the enumerable days in the `week`

  ## Examples

      iex> Cldr.Calendar.Interval.day 2019, 52, Cldr.Calendar.Fiscal.US
      Date.range(~D[2019-02-21 Cldr.Calendar.Fiscal.US], ~D[2019-02-21 Cldr.Calendar.Fiscal.US])

      iex> Cldr.Calendar.Interval.day 2019, 92, Cldr.Calendar.NRF
      Date.range(~D[2019-W14-1 Cldr.Calendar.NRF], ~D[2019-W14-1 Cldr.Calendar.NRF])

      iex> Cldr.Calendar.Interval.day 2019, 8, Cldr.Calendar.ISOWeek
      Date.range(~D[2019-W02-1 Cldr.Calendar.ISOWeek], ~D[2019-W02-1 Cldr.Calendar.ISOWeek])

  """
  @spec day(Calendar.year(), Calendar.day(), Cldr.Calendar.calendar()) ::
          Date.Range.t() | {:error, :invalid_date}
  @spec day(Date.t()) :: Date.Range.t()

  def day(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Cldr.Calendar.Gregorian}
    |> day()
    |> coerce_iso_calendar()
  end

  def day(date) do
    Date.range(date, date)
  end

  def day(year, day, calendar \\ Cldr.Calendar.Gregorian) do
    if day <= calendar.days_in_year(year) do
      iso_days = calendar.first_gregorian_day_of_year(year) + day - 1

      with {year, month, day} = calendar.date_from_iso_days(iso_days),
           {:ok, date} <- Date.new(year, month, day, calendar) do
        day(date)
      end
    else
      {:error, :invalid_date}
    end
  end

  @doc """
  Compare two date ranges.

  Uses [Allen's Interval Algebra](https://en.wikipedia.org/wiki/Allen%27s_interval_algebra)
  to return one of 13 different relationships:

  Relation	     | Converse
  ----------     | --------------
  :precedes	     | :preceded_by
  :meets         | :met_by
  :overlaps      | :overlapped_by
  :finished_by   | :finishes
  :contains      | :during
  :starts        | :started_by
  :equals        | :equals

  ## Arguments

  * `range_1` is a `Date.Range.t`

  * `range_2` is a `Date.Range.t`

  ## Returns

  An atom representing the relationship between the two ranges.

  ## Examples

      iex> Cldr.Calendar.Interval.compare Cldr.Calendar.Interval.day(~D[2019-01-01]),
      ...> Cldr.Calendar.Interval.day(~D[2019-01-02])
      :meets

      iex> Cldr.Calendar.Interval.compare Cldr.Calendar.Interval.day(~D[2019-01-01]),
      ...> Cldr.Calendar.Interval.day(~D[2019-01-03])
      :precedes

      iex> Cldr.Calendar.Interval.compare Cldr.Calendar.Interval.day(~D[2019-01-03]),
      ...> Cldr.Calendar.Interval.day(~D[2019-01-01])
      :preceded_by

      iex> Cldr.Calendar.Interval.compare Cldr.Calendar.Interval.day(~D[2019-01-02]),
      ...> Cldr.Calendar.Interval.day(~D[2019-01-01])
      :met_by

      iex> Cldr.Calendar.Interval.compare Cldr.Calendar.Interval.day(~D[2019-01-02]),
      ...> Cldr.Calendar.Interval.day(~D[2019-01-02])
      :equals

  """
  @spec compare(range_1 :: Date.Range.t(), range_2 :: Date.Range.t()) ::
          Cldr.Calendar.interval_relation()

  def compare(
        %Date.Range{first_in_iso_days: first, last_in_iso_days: last},
        %Date.Range{first_in_iso_days: first, last_in_iso_days: last}
      ) do
    :equals
  end

  def compare(%Date.Range{} = r1, %Date.Range{} = r2) do
    cond do
      r1.last_in_iso_days - r2.first_in_iso_days < -1 ->
        :precedes

      r1.last_in_iso_days - r2.first_in_iso_days == -1 ->
        :meets

      r1.first_in_iso_days < r2.first_in_iso_days && r1.last_in_iso_days > r2.last_in_iso_days ->
        :contains

      r1.last_in_iso_days == r2.last_in_iso_days && r1.first_in_iso_days < r2.first_in_iso_days ->
        :finished_by

      r1.first_in_iso_days == r2.first_in_iso_days && r1.last_in_iso_days < r2.last_in_iso_days ->
        :starts

      r2.last_in_iso_days - r1.first_in_iso_days < -1 ->
        :preceded_by

      r2.last_in_iso_days - r1.first_in_iso_days == -1 ->
        :met_by

      r2.last_in_iso_days == r1.last_in_iso_days && r2.first_in_iso_days < r1.first_in_iso_days ->
        :finishes

      r1.first_in_iso_days > r2.first_in_iso_days && r1.last_in_iso_days < r2.last_in_iso_days ->
        :during

      r2.first_in_iso_days == r1.first_in_iso_days && r1.last_in_iso_days > r2.last_in_iso_days ->
        :started_by

      r1.first_in_iso_days < r2.first_in_iso_days && r1.last_in_iso_days >= r2.first_in_iso_days ->
        :overlaps

      r2.last_in_iso_days >= r1.first_in_iso_days && r2.last_in_iso_days < r1.last_in_iso_days ->
        :overlapped_by
    end
  end

  @doc false
  def to_iso_calendar(%Date.Range{first: first, last: last}) do
    Date.range(Date.convert!(first, Calendar.ISO), Date.convert!(last, Calendar.ISO))
  end

  @doc false
  def coerce_iso_calendar(%Date.Range{first: first, last: last}) do
    first = %{first | calendar: Calendar.ISO}
    last = %{last | calendar: Calendar.ISO}
    Date.range(first, last)
  end
end
