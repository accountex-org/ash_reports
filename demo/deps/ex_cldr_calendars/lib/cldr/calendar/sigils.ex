defmodule Cldr.Calendar.Sigils do
  @moduledoc """
  Implements the `~d` sigils to produce
  dates, datetimes and naive datetimes.

  """

  alias Cldr.Config

  @doc """
  Implements a ~d sigil for expressing dates.

  Dates can be expressed in the following formats:

  * `~d[yyyy-mm-dd]` which produces a date in the `Cldr.Calendar.Gregorian` calendar
  * `~d[yyyy-Wmm-dd]` which produces a date in the `Cldr.Calendar.ISOWeek` calendar
  * `~d[yyyy-mm-dd calendar]` which produces a date in the given month-based calendar
  * `~d[yyyy-Wmm-dd calendar]` which produces a date in the given week-based calendar
  * `~d[yyyy-mm-dd C.E Julian]` which produces a date in the Cldr.Calendar.Julian calendar
  * `~d[yyyy-mm-dd B.C.E Julian]` which produces a date in the Cldr.Calendar.Julian calendar

  ## Examples

      iex> import Cldr.Calendar.Sigils
      iex> ~d[2019-01-01 Gregorian]
      ~d[2019-01-01 Gregorian]
      iex> ~d[2019-W01-01]
      ~d[2019-W01-1 ISOWeek]

  """
  defmacro sigil_d({:<<>>, _, [string]}, modifiers) do
    do_sigil_d(string, modifiers)
    |> Macro.escape()
  end

  def do_sigil_d(<<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, _) do
    to_date(year, month, day, Cldr.Calendar.Gregorian)
  end

  def do_sigil_d(<<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2, " C.E. Julian">>, _) do
    to_date(year, month, day, Cldr.Calendar.Julian)
  end

  def do_sigil_d(<<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2, " B.C.E. Julian">>, _) do
    to_date("-" <> year, month, day, Calendar.Julian)
  end

  def do_sigil_d(
        <<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2, " ", calendar::binary>>,
        _
      ) do
    to_date(year, month, day, calendar)
  end

  def do_sigil_d(
        <<"-", year::bytes-4, "-", month::bytes-2, "-", day::bytes-2, " ", calendar::binary>>,
        _
      ) do
    to_date("-" <> year, month, day, calendar)
  end

  def do_sigil_d(<<year::bytes-4, "-W", month::bytes-2, "-", day::bytes-2>>, _) do
    to_date(year, month, day, Cldr.Calendar.ISOWeek)
  end

  def do_sigil_d(<<year::bytes-4, "-W", month::bytes-2, "-", day::bytes-1>>, _) do
    to_date(year, month, day, Cldr.Calendar.ISOWeek)
  end

  def do_sigil_d(
        <<year::bytes-4, "-W", month::bytes-2, "-", day::bytes-2, " ", calendar::binary>>,
        _
      ) do
    to_date(year, month, day, calendar)
  end

  def do_sigil_d(
        <<year::bytes-4, "-W", month::bytes-2, "-", day::bytes-1, " ", calendar::binary>>,
        _
      ) do
    to_date(year, month, day, calendar)
  end

  defp to_date(year, month, day, calendar) do
    [year, month, day] = Enum.map([year, month, day], &String.to_integer/1)

    with {:ok, calendar} <- calendar_from_binary(calendar),
         {:ok, date} <- Date.new(year, month, day, calendar) do
      date
    end
  end

  defp calendar_from_binary(calendar) do
    inbuilt_calendar(calendar) ||
      fiscal_calendar(calendar) ||
      user_calendar(calendar) ||
      calendar_error(calendar)
  end

  defp inbuilt_calendar(calendar) do
    calendar = Module.concat(Cldr.Calendar, calendar)
    get_calendar(calendar)
  end

  defp fiscal_calendar(calendar) do
    calendar = Module.concat(Cldr.Calendar.FiscalYear, calendar)
    get_calendar(calendar)
  end

  defp user_calendar(calendar) do
    Module.concat("Elixir", calendar)
    |> get_calendar
  end

  defp get_calendar(calendar) do
    if Config.ensure_compiled?(calendar) and function_exported?(calendar, :cldr_calendar_type, 0) do
      {:ok, calendar}
    else
      nil
    end
  end

  defp calendar_error(calendar) do
    {:error, {Cldr.UnknownCalendarError, calendar}}
  end
end
