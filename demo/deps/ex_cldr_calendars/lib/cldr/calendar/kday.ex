defmodule Cldr.Calendar.Kday do
  @moduledoc """
  Provide K-Day functions for Dates, DateTimes and NaiveDateTimes.

  """

  import Cldr.Calendar,
    only: [
      date_to_iso_days: 1,
      date_from_iso_days: 2,
      iso_days_to_day_of_week: 1,
      weeks_to_days: 1
    ]

  @doc """
  Return the date of the `day_of_week` on or before the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

    * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      iex> Cldr.Calendar.Kday.kday_on_or_before(~D[2016-02-29], 2)
      ~D[2016-02-23]

      iex> Cldr.Calendar.Kday.kday_on_or_before(~D[2017-11-30], 1)
      ~D[2017-11-27]

      iex> Cldr.Calendar.Kday.kday_on_or_before(~D[2017-06-30], 6)
      ~D[2017-06-24]

      iex> Cldr.Calendar.Kday.kday_on_or_before(~D[2023-09-29], 5)
      ~D[2023-09-29]

  """
  @spec kday_on_or_before(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def kday_on_or_before(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> kday_on_or_before(k)
    |> date_from_iso_days(calendar)
  end

  def kday_on_or_before(iso_days, k) when is_integer(iso_days) do
    iso_days - iso_days_to_day_of_week(iso_days - k)
  end

  @doc """
  Return the date of the `day_of_week` on or after the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

    * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument

  ## Examples

      iex> Cldr.Calendar.Kday.kday_on_or_after(~D[2016-02-29], 2)
      ~D[2016-03-01]

      iex> Cldr.Calendar.Kday.kday_on_or_after(~D[2017-11-30], 1)
      ~D[2017-12-04]

      iex> Cldr.Calendar.Kday.kday_on_or_after(~D[2017-06-30], 6)
      ~D[2017-07-01]

      iex> Cldr.Calendar.Kday.kday_on_or_after(~D[2023-09-29], 5)
      ~D[2023-09-29]

  """
  @spec kday_on_or_after(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def kday_on_or_after(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> kday_on_or_after(k)
    |> date_from_iso_days(calendar)
  end

  def kday_on_or_after(iso_days, k) when is_integer(iso_days) do
    kday_on_or_before(iso_days + 6, k)
  end

  @doc """
  Return the date of the `day_of_week` nearest the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      iex> Cldr.Calendar.Kday.kday_nearest(~D[2016-02-29], 2)
      ~D[2016-03-01]

      iex> Cldr.Calendar.Kday.kday_nearest(~D[2017-11-30], 1)
      ~D[2017-11-27]

      iex> Cldr.Calendar.Kday.kday_nearest(~D[2017-06-30], 6)
      ~D[2017-07-01]

  """
  @spec kday_nearest(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def kday_nearest(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> kday_nearest(k)
    |> date_from_iso_days(calendar)
  end

  def kday_nearest(iso_days, k) when is_integer(iso_days) do
    kday_on_or_before(iso_days + 3, k)
  end

  @doc """
  Return the date of the `day_of_week` before the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      iex> Cldr.Calendar.Kday.kday_before(~D[2016-02-29], 2)
      ~D[2016-02-23]

      iex> Cldr.Calendar.Kday.kday_before(~D[2017-11-30], 1)
      ~D[2017-11-27]

      iex> Cldr.Calendar.Kday.kday_before(~D[2023-09-30], 5)
      ~D[2023-09-29]

      # 6 means Saturday.  Use either the integer value or the atom form.
      iex> Cldr.Calendar.Kday.kday_before(~D[2017-06-30], 6)
      ~D[2017-06-24]

  """
  @spec kday_before(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def kday_before(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> kday_before(k)
    |> date_from_iso_days(calendar)
  end

  def kday_before(iso_days, k) do
    kday_on_or_before(iso_days - 1, k)
  end

  @doc """
  Return the date of the `day_of_week` after the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      iex> Cldr.Calendar.Kday.kday_after(~D[2016-02-29], 2)
      ~D[2016-03-01]

      iex> Cldr.Calendar.Kday.kday_after(~D[2017-11-30], 1)
      ~D[2017-12-04]

      iex> Cldr.Calendar.Kday.kday_after(~D[2017-06-30], 6)
      ~D[2017-07-01]

      iex> Cldr.Calendar.Kday.kday_after(~D[2021-03-28], 7)
      ~D[2021-04-04]

  """
  @spec kday_after(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def kday_after(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> kday_after(k)
    |> date_from_iso_days(calendar)
  end

  def kday_after(iso_days, k) do
    kday_on_or_after(iso_days + 1, k)
  end

  @doc """
  Return the date of the `nth` `day_of_week` on or before/after the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `n` is the cardinal number of `k` before (negative `n`) or after
    (positive `n`) the specified date.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      # Thanksgiving in the US
      iex> Cldr.Calendar.Kday.nth_kday(~D[2017-11-01], 4, 4)
      ~D[2017-11-23]

      # Labor day in the US
      iex> Cldr.Calendar.Kday.nth_kday(~D[2017-09-01], 1, 1)
      ~D[2017-09-04]

      # Daylight savings time starts in the US
      iex> Cldr.Calendar.Kday.nth_kday(~D[2017-03-01], 2, 7)
      ~D[2017-03-12]

  """
  @spec nth_kday(Calendar.day() | Date.t(), integer(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def nth_kday(%{year: _, month: _, day: _, calendar: calendar} = date, n, k)
      when k in 1..7 and is_integer(n) do
    date
    |> date_to_iso_days
    |> nth_kday(n, k)
    |> date_from_iso_days(calendar)
  end

  def nth_kday(gregorian_days, n, k) when is_integer(gregorian_days) and n > 0 do
    kday_on_or_after(gregorian_days, k) + weeks_to_days(n - 1)
  end

  def nth_kday(gregorian_days, n, k) when is_integer(gregorian_days) do
    kday_on_or_before(gregorian_days, k) + weeks_to_days(n + 1)
  end

  @doc """
  Return the date of the first `day_of_week` on or after the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument.

  ## Examples

      # US election day
      iex> Cldr.Calendar.Kday.first_kday(~D[2017-11-02], 2)
      ~D[2017-11-07]

      # US Daylight savings end
      iex> Cldr.Calendar.Kday.first_kday(~D[2017-11-01], 7)
      ~D[2017-11-05]

  """
  @spec first_kday(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def first_kday(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> first_kday(k)
    |> date_from_iso_days(calendar)
  end

  def first_kday(iso_days, k) do
    nth_kday(iso_days, 1, k)
  end

  @doc """
  Return the date of the last `day_of_week` on or before the
  specified `date`.

  ## Arguments

  * `date` is `t:Date.t/0`, a `t:DateTime.t/0`, `t:NaiveDateTime.t/0` or
    ISO days since epoch.

  * `k` is an integer day of the week where `1` is
    Monday and `7` is Sunday.

  ## Returns

  * A `t:Date.t/0` in the calendar of the date provided as an argument

  ## Example

      # Memorial Day in the US
      iex> Cldr.Calendar.Kday.last_kday(~D[2017-05-31], 1)
      ~D[2017-05-29]

  """
  @spec last_kday(Calendar.day() | Date.t(), Cldr.Calendar.day_of_week()) ::
          Calendar.day() | Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def last_kday(%{year: _, month: _, day: _, calendar: calendar} = date, k)
      when k in 1..7 do
    date
    |> date_to_iso_days
    |> last_kday(k)
    |> date_from_iso_days(calendar)
  end

  def last_kday(iso_days, k) do
    nth_kday(iso_days, -1, k)
  end
end
