defmodule Cldr.Calendar.Duration do
  @moduledoc """
  Functions to create and format a difference between
  two dates, times or datetimes.

  The difference between two dates (or times or datetimes) is
  usually defined in terms of days or seconds.

  A duration is calculated as the difference in time in calendar
  units: years, months, days, hours, minutes, seconds and microseconds.

  This is useful to support formatting a string for users in
  easy-to-understand terms. For example `11 months, 3 days and 4 minutes`
  is a lot easier to understand than `28771440` seconds.

  The package [ex_cldr_units](https://hex.pm/packages/ex_cldr_units) can
  be optionally configured to provide localized formatting of durations.

  If configured, the following providers should be configured in the
  appropriate CLDR backend module. For example:

  ```elixir
  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "ja"],
      providers: [Cldr.Calendar, Cldr.Number, Cldr.Unit, Cldr.List]
  end
  ```

  """

  @struct_list [year: 0, month: 0, day: 0, hour: 0, minute: 0, second: 0, microsecond: {0, 6}]
  @keys Keyword.keys(@struct_list)
  defstruct @struct_list

  @typedoc "Duration in calendar units"
  @type t :: %__MODULE__{
          year: non_neg_integer(),
          month: non_neg_integer(),
          day: non_neg_integer(),
          hour: non_neg_integer(),
          minute: non_neg_integer(),
          second: non_neg_integer(),
          microsecond: {integer(), 1..6}
        }

  @typedoc "A date, time, naivedatetime or datetime"
  @type date_or_time_or_datetime ::
          Calendar.date()
          | Calendar.time()
          | Calendar.datetime()
          | Calendar.naive_datetime()

  @typedoc "A interval as either Date.Range.t() CalendarInterval.t()"
  @type interval :: Date.Range.t() | CalendarInterval.t()

  @microseconds_in_second 1_000_000
  @microseconds_in_day 86_400_000_000

  if Code.ensure_loaded?(Cldr.Unit) do
    @doc """
    Returns a string formatted representation of
    a duration.

    Note that time units that are zero are omitted
    from the output.

    Formatting is

    ## Arguments

    * `duration` is a duration of type `t:Cldr.Calendar.Duration.t/0` returned
      by `Cldr.Calendar.Duration.new/2`

    * `options` is a Keyword list of options

    ## Options

    * `:except` is a list of time units to be omitted from
      the formatted output. It may be useful to use
      `except: [:microsecond]` for example. The default is
      `[]`.

    * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
      or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`
      The default is `Cldr.get_locale/0`

    * `backend` is any module that includes `use Cldr` and therefore
      is a `Cldr` backend module. The default is `Cldr.default_backend/0`

    * `:list_options` is a list of options passed to `Cldr.List.to_string/3` to
      control the final list output.

    Any other options are passed to `Cldr.Number.to_string/3` and
    `Cldr.Unit.to_string/3` during the formatting process.

    ## Note

    * Any duration parts that are `0` are not output.

    ## Example

        iex> {:ok, duration} = Cldr.Calendar.Duration.new(~D[2019-01-01], ~D[2019-12-31])
        iex> Cldr.Calendar.Duration.to_string(duration)
        {:ok, "11 months and 30 days"}

    """
    def to_string(%__MODULE__{} = duration, options \\ []) do
      {except, options} = Keyword.pop(options, :except, [])

      for key <- @keys,
          value = Map.get(duration, key),
          maybe_extract_microseconds(key, value) != 0 && key not in except do
        value = maybe_extract_microseconds(key, value)
        Cldr.Unit.new!(key, value)
      end
      |> Cldr.Unit.to_string(options)
    end

    @doc """
    Formats a duration as a string or raises
    an exception on error.

    ## Arguments

    * `duration` is a duration of type `t:Cldr.Calendar.Duration.t/0` returned
      by `Cldr.Calendar.Duration.new/2`.

    * `options` is a Keyword list of options.

    ## Options

    See `Cldr.Calendar.Duration.to_string/2`.

    ## Returns

    * A formatted string or

    * raises an exception.

    """

    @spec to_string!(t(), Keyword.t()) :: String.t() | no_return
    def to_string!(%__MODULE__{} = duration, options \\ []) do
      case to_string(duration, options) do
        {:ok, string} -> string
        {:error, {exception, reason}} -> raise exception, reason
      end
    end
  else
    @doc """
    Returns a string formatted representation of
    a duration.

    Note that time units that are zero are omitted
    from the output.

    ## Localized formatting

    If localized formatting of a duration is desired,
    add `{:ex_cldr_units, "~> 2.0"}` to your `mix.exs`
    and ensure you have configured your providers in
    your backend configuration to include: `providers:
    [Cldr.Calendar, Cldr.Number, Cldr.Unit, Cldr.List]`

    ## Arguments

    * `duration` is a duration of type `t:Cldr.Calendar.Duration.t/0` returned
      by `Cldr.Calendar.Duration.new/2`

    * `options` is a Keyword list of options

    ## Options

    * `:except` is a list of time units to be omitted from
      the formatted output. It may be useful to use
      `except: [:microsecond]` for example. The default is
      `[]`.

    ## Example

        iex> {:ok, duration} = Cldr.Calendar.Duration.new(~D[2019-01-01], ~D[2019-12-31])
        iex> Cldr.Calendar.Duration.to_string(duration)
        {:ok, "11 months, 30 days"}

    """
    def to_string(%__MODULE__{} = duration, options \\ []) do
      except = Keyword.get(options, :except, [])

      formatted =
        for key <- @keys,
            value = Map.get(duration, key),
            maybe_extract_microseconds(key, value) != 0 && key not in except do
          value = maybe_extract_microseconds(key, value)
          if value > 1, do: "#{value} #{key}s", else: "#{value} #{key}"
        end
        |> Enum.join(", ")

      {:ok, formatted}
    end

    @doc """
    Formats a duration as a string or raises
    an exception on error.

    ## Arguments

    * `duration` is a duration of type `t:Cldr.Calendar.Duration.t/0` returned
      by `Cldr.Calendar.Duration.new/2`.

    * `options` is a Keyword list of options.

    ## Options

    See `Cldr.Calendar.Duration.to_string/2`.

    ## Returns

    * A formatted string or

    * raises an exception.

    """

    @spec to_string!(t(), Keyword.t()) :: String.t() | no_return
    def to_string!(%__MODULE__{} = duration, options \\ []) do
      {:ok, string} = to_string(duration, options)
      string
    end
  end

  defp maybe_extract_microseconds(:microsecond, {microseconds, _precision}), do: microseconds
  defp maybe_extract_microseconds(_any, value), do: value

  @doc """
  Calculates the calendar difference between two dates
  returning a `Duration` struct.

  The difference calculated is in terms of years, months,
  days, hours, minutes, seconds and microseconds.

  ## Arguments

  * `from` is a date, time or datetime representing the
    start of the duration.

  * `to` is a date, time or datetime representing the
    end of the duration

  ## Notes

  * `from` must be before or at the same time
    as `to`. In addition, both `from` and `to` must
    be in the same calendar

  * If `from` and `to` are `datetime`s then
    they must both be in the same time zone

  ## Returns

  * A `{:ok, duration}` tuple or a

  * `{:error, {exception, reason}}` tuple

  ## Example

      iex> Cldr.Calendar.Duration.new(~D[2019-01-01], ~D[2019-12-31])
      {:ok,
       %Cldr.Calendar.Duration{
         year: 0,
         month: 11,
         day: 30,
         hour: 0,
         microsecond: {0, 6},
         minute: 0,
         second: 0
       }}

  """

  @spec new(from :: date_or_time_or_datetime(), to :: date_or_time_or_datetime()) ::
          {:ok, t()}
          | {:error, {module(), String.t()}}
          | {:ambiguous, DateTime.t(), DateTime.t()}
          | {:gap, DateTime.t(), DateTime.t()}

  def new(unquote(Cldr.Calendar.datetime()) = from, unquote(Cldr.Calendar.datetime()) = to) do
    with :ok <- confirm_same_time_zone(from, to),
         :ok <- confirm_date_order(from, to) do
      time_diff = time_duration(from, to)
      date_diff = date_duration(from, to)
      apply_time_diff_to_duration(date_diff, time_diff, from)
    end
  end

  def new(unquote(Cldr.Calendar.date()) = from, unquote(Cldr.Calendar.date()) = to) do
    with {:ok, from} <- cast_date_time(from),
         {:ok, to} <- cast_date_time(to) do
      new(from, to)
    end
  end

  def new(unquote(Cldr.Calendar.time()) = from, unquote(Cldr.Calendar.time()) = to) do
    with {:ok, from} <- cast_date_time(from),
         {:ok, to} <- cast_date_time(to) do
      time_diff = time_duration(from, to)
      {seconds, microseconds} = Cldr.Math.div_mod(time_diff, 1_000_000)
      {minutes, seconds} = Cldr.Math.div_mod(seconds, 60)
      {hours, minutes} = Cldr.Math.div_mod(minutes, 60)

      {:ok,
       struct(__MODULE__,
         hour: hours,
         minute: minutes,
         second: seconds,
         microsecond: microsecond_precision(microseconds)
       )}
    end
  end

  @doc """
  Calculates the calendar difference in
  a `Date.Range` or `CalendarInterval`
  returning a `Duration` struct.

  The difference calculated is in terms of years, months,
  days, hours, minutes, seconds and microseconds.

  ## Arguments

  * `interval` is either `t:Date.Range.t/0` or a
    `CalendarInterval.t()`

  ## Returns

  * A `{:ok, duration}` tuple or a

  * `{:error, {exception, reason}}` tuple

  ## Notes

  * `CalendarInterval` is defined by the most wonderful
    [calendar_interval](https://hex.pm/packages/calendar_interval)
    library.

  ## Example

      iex> Cldr.Calendar.Duration.new(Date.range(~D[2019-01-01], ~D[2019-12-31]))
      {:ok,
       %Cldr.Calendar.Duration{
         year: 0,
         month: 11,
         day: 30,
         hour: 0,
         microsecond: {0, 6},
         minute: 0,
         second: 0
       }}

  """
  @spec new(interval :: interval()) ::
          {:ok, t()}
          | {:error, {module(), String.t()}}
          | {:ambiguous, DateTime.t(), DateTime.t()}
          | {:gap, DateTime.t(), DateTime.t()}

  if Code.ensure_loaded?(CalendarInterval) do
    def new(%CalendarInterval{first: first, last: last, precision: precision} = _interval)
        when precision in [:year, :month, :day] do
      first = %{first | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
      last = %{last | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
      new(first, last)
    end

    def new(%CalendarInterval{first: first, last: last}) do
      new(first, last)
    end
  end

  def new(%Date.Range{first: first, last: last}) do
    new(first, last)
  end

  defp apply_time_diff_to_duration(date_diff, time_diff, from) do
    duration =
      if time_diff < 0 do
        back_one_day(date_diff, from)
        |> merge(@microseconds_in_day + time_diff)
      else
        date_diff |> merge(time_diff)
      end

    {:ok, duration}
  end

  def new(%{calendar: _calendar1} = from, %{calendar: _calendar2} = to) do
    {:error,
     {Cldr.IncompatibleCalendarError,
      "The two dates must be in the same calendar. Found #{inspect(from)} and #{inspect(to)}"}}
  end

  @doc """
  Returns a duration calculated from a number of seconds.

  The duration will be calculated in hours, minutes,
  seconds and microseconds only.

  ### Arguments

  * `seconds` is a number of seconds as a float or
    integer.

  ### Returns

  * a `t:Cldr.Calendar.Duration.t/0`

  ### Example

      iex> Cldr.Calendar.Duration.new_from_seconds(36092.1)
      %Cldr.Calendar.Duration{
        year: 0,
        month: 0,
        day: 0,
        hour: 10,
        minute: 1,
        second: 32,
        microsecond: {100000, 1}
      }

  """
  @doc since: "1.26.0"
  @spec new_from_seconds(seconds :: number()) :: t()
  def new_from_seconds(seconds) when is_number(seconds) do
    microseconds = microseconds_from_fraction(seconds)
    seconds = trunc(seconds)
    hours = div(seconds, 3600)
    remainder = rem(seconds, 3600)
    minutes = div(remainder, 60)
    seconds = rem(remainder, 60)

    %__MODULE__{
      year: 0,
      month: 0,
      day: 0,
      hour: hours,
      minute: minutes,
      second: seconds,
      microsecond: microseconds
    }
  end

  defp microseconds_from_fraction(number) do
    fraction = Cldr.Digits.fraction_as_integer(number)

    cond do
      fraction == 0 -> {0, 6}
      fraction < 10 -> {fraction * 100_000, 1}
      fraction < 100 -> {fraction * 10_000, 2}
      fraction < 1_000 -> {fraction * 1_000, 3}
      fraction < 10_000 -> {fraction * 100, 4}
      fraction < 100_000 -> {fraction * 10, 5}
      fraction <= 1_000_000 -> {fraction, 6}
    end
  end

  defp microsecond_precision(microseconds) do
    cond do
      microseconds == 0 -> {0, 6}
      microseconds < 10 -> {microseconds, 1}
      microseconds < 100 -> {microseconds, 2}
      microseconds < 1_000 -> {microseconds, 3}
      microseconds < 10_000 -> {microseconds, 4}
      microseconds < 100_000 -> {microseconds, 5}
      microseconds <= 1_000_000 -> {microseconds, 6}
    end
  end

  defp cast_date_time(unquote(Cldr.Calendar.datetime()) = datetime) do
    _ = calendar
    {:ok, datetime}
  end

  defp cast_date_time(unquote(Cldr.Calendar.naivedatetime()) = naivedatetime) do
    _ = calendar
    DateTime.from_naive(naivedatetime, "Etc/UTC")
  end

  defp cast_date_time(unquote(Cldr.Calendar.date()) = date) do
    {:ok, dt} = NaiveDateTime.new(date.year, date.month, date.day, 0, 0, 0, {0, 6}, calendar)
    DateTime.from_naive(dt, "Etc/UTC")
  end

  defp cast_date_time(unquote(Cldr.Calendar.time()) = time) do
    {:ok, dt} =
      NaiveDateTime.new(
        1,
        1,
        1,
        time.hour,
        time.minute,
        time.second,
        time.microsecond,
        Calendar.ISO
      )

    DateTime.from_naive(dt, "Etc/UTC")
  end

  defp confirm_date_order(from, to) do
    if DateTime.compare(from, to) in [:lt, :eq] do
      :ok
    else
      {:error,
       {
         Cldr.InvalidDateOrder,
         "`from` must be earlier or equal to `to`. " <>
           "Found #{inspect(from)} and #{inspect(to)}"
       }}
    end
  end

  defp confirm_same_time_zone(%{time_zone: zone}, %{time_zone: zone}) do
    :ok
  end

  defp confirm_same_time_zone(from, to) do
    {:error,
     {Cldr.IncompatibleTimeZone,
      "`from` and `to` must be in the same time zone. " <>
        "Found #{inspect(from)} and #{inspect(to)}"}}
  end

  @doc """
  Calculates the calendar difference between two dates
  returning a `Duration` struct.

  The difference calculated is in terms of years, months,
  days, hours, minutes, seconds and microseconds.

  ## Arguments

  * `from` is a date, time or datetime representing the
    start of the duration

  * `to` is a date, time or datetime representing the
    end of the duration

  Note that `from` must be before or at the same time
  as `to`. In addition, both `from` and `to` must
  be in the same calendar.

  ## Returns

  * A `t:Cldr.Calendar.Duration.t/0` struct or

  * raises an exception

  ## Example

      iex> Cldr.Calendar.Duration.new!(~D[2019-01-01], ~D[2019-12-31])
      %Cldr.Calendar.Duration{
        year: 0,
        month: 11,
        day: 30,
        hour: 0,
        microsecond: {0, 6},
        minute: 0,
        second: 0
      }

  """

  @spec new!(from :: date_or_time_or_datetime(), to :: date_or_time_or_datetime()) ::
          t() | no_return()

  def new!(from, to) do
    case new(from, to) do
      {:ok, duration} -> duration
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  @doc """
  Calculates the calendar difference in
  a `Date.Range` or `CalendarInterval`
  returning a `Duration` struct.

  The difference calculated is in terms of years, months,
  days, hours, minutes, seconds and microseconds.

  ## Arguments

  * `interval` is either ` Date.Range.t()` or a
    `CalendarInterval.t()`

  ## Returns

  * A `t:Cldr.Calendar.Duration.t/0` struct or

  * raises an exception

  ## Notes

  * `CalendarInterval` is defined by the most wonderful
    [calendar_interval](https://hex.pm/packages/calendar_interval)
    library.

  ## Example

      iex> Cldr.Calendar.Duration.new!(Date.range(~D[2019-01-01], ~D[2019-12-31]))
      %Cldr.Calendar.Duration{
        year: 0,
        month: 11,
        day: 30,
        hour: 0,
        microsecond: {0, 6},
        minute: 0,
        second: 0
      }

  """

  @spec new!(interval()) :: t() | no_return()

  def new!(interval) do
    case new(interval) do
      {:ok, duration} -> duration
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  defp time_duration(unquote(Cldr.Calendar.time()) = from, unquote(Cldr.Calendar.time()) = to) do
    Time.diff(to, from, :microsecond)
  end

  # The two dates are the same so there is no duration
  @doc false
  def date_duration(
        %{year: year, month: month, day: day, calendar: calendar},
        %{year: year, month: month, day: day, calendar: calendar}
      ) do
    %__MODULE__{}
  end

  # Two dates in the same calendar can be used
  def date_duration(%{calendar: calendar} = from, %{calendar: calendar} = to) do
    increment =
      if from.day > to.day do
        calendar.days_in_month(from.year, from.month)
      else
        0
      end

    {day_diff, increment} =
      if increment != 0 do
        {increment + to.day - from.day, 1}
      else
        {to.day - from.day, 0}
      end

    {month_diff, increment} =
      if from.month + increment > to.month do
        {to.month + calendar.months_in_year(to.year) - from.month - increment, 1}
      else
        {to.month - from.month - increment, 0}
      end

    year_diff = to.year - from.year - increment

    %__MODULE__{year: year_diff, month: month_diff, day: day_diff}
  end

  # When we have a negative time duration then
  # we need to apply a one day adjustment to
  # the date difference
  defp back_one_day(date_diff, calendar) do
    back_one_day(date_diff, :day, calendar)
  end

  defp back_one_day(%{day: 0} = date_diff, :day, from) do
    months_in_year = Cldr.Calendar.months_in_year(from)
    previous_month = Cldr.Math.amod(from.month - 1, months_in_year)
    days_in_month = from.calendar.days_in_month(from.year, previous_month)

    %{date_diff | day: days_in_month}
    |> back_one_day(:month, from)
  end

  defp back_one_day(%{day: day} = date_diff, :day, _from) do
    %{date_diff | day: day - 1}
  end

  defp back_one_day(%{month: 0} = date_diff, :month, from) do
    months_in_year = Cldr.Calendar.months_in_year(from)

    %{date_diff | month: months_in_year}
    |> back_one_day(:year, from)
  end

  defp back_one_day(%{month: month} = date_diff, :month, _from) do
    %{date_diff | month: month - 1}
  end

  defp back_one_day(%{year: year} = date_diff, :year, _from) do
    %{date_diff | year: year - 1}
  end

  defp merge(duration, microseconds) do
    {seconds, microseconds} = Cldr.Math.div_mod(microseconds, @microseconds_in_second)
    {hours, minutes, seconds} = :calendar.seconds_to_time(seconds)

    duration
    |> Map.put(:hour, hours)
    |> Map.put(:minute, minutes)
    |> Map.put(:second, seconds)
    |> Map.put(:microsecond, microsecond_precision(microseconds))
  end
end
