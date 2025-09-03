# Cldr Calendars

![Build status](https://github.com/elixir-cldr/cldr_calendars/actions/workflows/ci.yml/badge.svg)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_cldr_calendars.svg)](https://hex.pm/packages/ex_cldr_calendars)
[![Hex.pm](https://img.shields.io/hexpm/dw/ex_cldr_calendars.svg?)](https://hex.pm/packages/ex_cldr_calendars)
[![Hex.pm](https://img.shields.io/hexpm/dt/ex_cldr_calendars.svg?)](https://hex.pm/packages/ex_cldr_calendars)
[![Hex.pm](https://img.shields.io/hexpm/l/ex_cldr_calendars.svg)](https://hex.pm/packages/ex_cldr_calendars)

> My wife's jealousy is getting ridiculous. The other day she looked at my calendar and wanted to know who May was.
> -- Rodney Dangerfield

# Introduction

Calendars are curious things. For centuries people from all cultures have sought to impose human order on the astronomical movements of the earth and moon. Today, despite much of the world converging on the [Proleptic Gregorian](https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar) calendar, there remain many derivative and alternative ways for humans to organise the passage of time.

`Cldr Calendars` builds on Elixir's standard `Calendar` module to provide additional calendars and calendar functionality intended to be of practical use.  In particular `Cldr Calendars`:

* Provides support for configurable month-based and week-based calendars that are in common use as [Fiscal Year](https://en.wikipedia.org/wiki/Fiscal_year) calendars for countries and organizations around the world. See `Cldr.Calendar.new/3`

* Supports localisation of common calendar terms such as *day of the week* and *month of the year* using the [CLDR](https://cldr.unicode.org) data that is available for over 500 locales. See `Cldr.Calendar.localize/3`

* Supports locale-specific knowledge of what is a weekend or a workday. See `Cldr.Calendar.weekend/1`, `Cldr.Calendar.weekend?/2`, `Cldr.Calendar.weekdays/1` and `Cldr.Calendar.weekday?/2`.

* Provides convenient `Date.Range` calculators for years, quarters, months and weeks for calendars and provides the means to move to the `next` and `previous` period in a calendar where a period may be a year, quarter, month, week or day.

* Supports adding or subtracting periods to dates and date ranges. See `Cldr.Calendar.plus/3` and `Cldr.Calendar.minus/3`

* Includes pre-defined calendars for Gregorian (compatible with the builtin `Calendar` module), `ISOWeek` and `National Retail Federation (NRF)` calendars

* Includes returning a calendar configured to reflect the `first_day_of_week` and `min_days_in_first_week` for a given territory lor locale.  See `Cldr.Calendar.calendar_for_locale/2`.

* Includes functions to find the first, last, nearest and `nth` days of the week from a date. For example, find the `2nd Tuesday in November`.

**See the documentation for `Cldr.Calendar` for the main public API.**

## Cldr Calendars Installation

Add `ex_cldr_calendars` to your `deps` in `mix.exs`. **Note that `ex_cldr_calendars` is supported on Elixir 1.11 and later only**.

```elixir
def deps do
  [
    {:ex_cldr_calendars, "~> 1.26"}
    ...
  ]
end
```

## Getting Started

Let's say you work for [Cisco Systems](https://cisco.com). Your learn that the financial year ends on the last Saturday of July. To make things easy you'd like to compare the results of this financial year to last finanical year.  And you'd like to know how many days are left this quarter in order to achieve your sales targets.

Here's how we do that:

### Define a calendar that represents Cisco's financial year

Each calendar is defined as a module that implements both the `Calendar` and `Cldr.Calendar` behaviours.  The details of how that is achieved isn't important at this stage.  Its easy to define your own calendar module through some configuration parameters.  Here's how we do that for Cisco:
```
defmodule Cldr.Calendar.CSCO do
  use Cldr.Calendar.Base.Week,
    first_or_last: :last,
    day_of_year_: 6,
    month_of_year_: 7
end
```
This configuration says that the calendar is defined as `first_or_last: :last` which means we are defining a calendar in terms of when it ends (you can of course also define a calendar in terms of when it starts by setting this to `:first`).

The `:day_of_year` day is Saturday, which is in `Calendar` speak, the sixth day of the week.  Days of the week are numbered from `1` for Monday to `7` to Sunday.

The `:month_of_year` is July.  Months are numbered from January being `1` to December being `12`.

There we have it, a calendar that is based upon the definition of "ends on the last Saturday of July".

### Dates in Cisco's calendar

You might be wondering, how to we represent dates in a customised calendar like this? Thanks to the flexibility of Elixir's standard `Calendar` module, we can leverage existing functions to build a date.  Lets build a date which is the first day of Cisco's financial year for 2019.
```
{:ok, date} = Date.new(2019, 1, 1, Cldr.Calendar.CSCO)
{:ok, ~d[2019-W01-1 CSCO]}
```
That was easy.  All dates are specified *in the context of the specific calendar*.  We don't need to know what the equivalent Gregorian calendar date is.  But we can find out if we want to:
```
iex> Date.convert date, Calendar.ISO
{:ok, ~D[2018-07-29]}
```
Which you will see is July 29th, 2018 - a Sunday.  Since we specified that the `:last` day of the year is a Saturday this makes sense.  You will also note that this is a date in 2018 as it should be. The year ends in July so it must start around 12 months earlier - in July of 2018.

This would also mean that the last day of Fiscal Year 2018 must be July 28th, 2018.  Lets check:
```
iex> Cldr.Calendar.last_gregorian_day_of_year(2018, Cldr.Calendar.CSCO)
~d[2018-07-28 Gregorian]
```
Which you will see is the last Saturday in July for 2018.

### Years, quarters, months, weeks and days

A common activity with calendars is selecting data in certain date ranges or iterating over those same ranges. `Cldr Calendars` makes that easy.

Want to know what is the first quarter of Cisco's financial year in 2019?
```
 iex> range = Cldr.Calendar.Interval.quarter 2019, 1, Cldr.Calendar.CSCO
 #DateRange<~d[2019-W01-1 CSCO], ~d[2019-W13-7 CSCO]>
```
A `Date.Range.t` is returned which can be enumerated with any of Elixir's [Enum](https://hexdocs.pm/elixir/Enum.html) or [Stream](https://hexdocs.pm/elixir/Stream.html) functions. The same applies for `year`, `month`, `week` and `day`.

Let's list all of the days Cisco's first quarter:
```
iex> Enum.map range, &Cldr.Calendar.date_to_string/1
["2019-W01-1", "2019-W01-2", "2019-W01-3", "2019-W01-4", "2019-W01-5",
 "2019-W01-6", "2019-W01-7", "2019-W02-1", "2019-W02-2", "2019-W02-3",
 "2019-W02-4", "2019-W02-5", "2019-W02-6", "2019-W02-7", "2019-W03-1",
 "2019-W03-2", "2019-W03-3", "2019-W03-4", "2019-W03-5", "2019-W03-6",
 "2019-W03-7", "2019-W04-1", "2019-W04-2", "2019-W04-3", "2019-W04-4",
 "2019-W04-5", "2019-W04-6", "2019-W04-7", "2019-W05-1", "2019-W05-2",
 "2019-W05-3", "2019-W05-4", "2019-W05-5", "2019-W05-6", "2019-W05-7",
 "2019-W06-1", "2019-W06-2", "2019-W06-3", "2019-W06-4", "2019-W06-5",
 "2019-W06-6", "2019-W06-7", "2019-W07-1", "2019-W07-2", "2019-W07-3",
 "2019-W07-4", "2019-W07-5", "2019-W07-6", "2019-W07-7", "2019-W08-1", ...]
```
But wait a minute, these don't look like familiar dates!  Shouldn't they be formatted as "yyy-mm-dd"? The answer in this case is "no".

If you look carefully at where we asked for the date range for Cisco's first quarter of 2019 you will see `%Date{calendar: Cldr.Calendar.CSCO, day: 7, month: 13, year: 2019}` as the last date in the range. There is, of course, no such month as `13` in the Gregorian calendar.  What's going on?

## Week-based calendars

Cisco's calendar is an example of a "week-based" calendar. Such week-based calendars are examples of [fiscal year calendars](https://en.wikipedia.org/wiki/Fiscal_year). In `Cldr Calendar`, any calendar that is defined in terms of "[first | last] [day_of_week] of [month_of_year_]" is a week-based calendar.  These calendars have a year of 52 weeks duration except in "leap years" that have 53 weeks.

The most well-known week-based calendar may be the [ISO Week Calendar](https://en.wikipedia.org/wiki/ISO_week_date). How would we define that calendar in `Cldr Calendars`? Easy!
```
defmodule Cldr.Calendar.ISOWeek do
  use Cldr.Calendar.Base.Week,
    day: 1,
    min_days_in_first_week: 4
end
```
This says that the calendar starts on the first Monday in January. How do we know that?  It's because
`:month_of_year` defaults to `1` (January) and `:first_or_last` defaults to `:first`.

Lets see what the first day of 2019 is in the `ISOWeek` calendar.
```
iex> date = Cldr.Calendar.first_day_of_year(2019, Cldr.Calendar.ISOWeek)
~d[2019-W01-1 ISOWeek]
```
As expected, the date is expressed in terms of the calendar `Cldr.Calendar.ISOWeek`. What's the equivalent Gregorian day?
```
iex> Date.convert(date, Calendar.ISO)
{:ok, ~D[2018-12-31]}
```
That's interesting.  The first day of the 2019 year in the ISO Week calendar is actually December 31st, 2018. Why is that?

Week-based calendars can start or end on a given day of the week in a given month.  But there is a third option: the given day of the week *nearest* to the start or end of the given month.  This is indicated by the configuration parameter `:min_days_in_first_week`.  For the `ISO Week` calendar we have `min_days_in_first_week: 4`.  That means that at least `4` days of the first or last week have to be in the specified `:month_of_year` and then we select the nearest day of the week.  Hence it is possible and even common for the gregorian start of the year for a week-based calendar to be up to 6 days before or after the Gregorian start of the year.

What's the last week of 2019 in the `ISO Week` calendar?
```
 iex> date = Cldr.Calendar.Interval.week(2019, 52, Cldr.Calendar.ISOWeek)
 #DateRange<~d[2019-W52-1 ISOWeek], ~d[2019-W52-7 ISOWeek]>
```
You'll see that for week-based calendars the date is actually stored as `year, week, day` where the `:month` field of the `Date.t` is actually the week in the year and `:day` is the day in the week.

## Month-based calendars

The Gregorian calendar is the canonical example of a month-based calendar. It starts on January 1st and ends on December 31st each year.  But not all calendars start in January and end in December.

* The United States fiscal year starts on October 1st and ends on September 30th
* The United Kingdom fiscal year starts on April 1st and ends on March 31st
* The Australian fiscal year starts on July 1st and ends on June 30th

`Cldr Calendars` allows month-based calendars to be defined based upon the first or last gregorian month of the year for that calendar.

Of course sometimes we also want to refer to weeks within a year although this is less common than referring to days within months.  Nevertheless, a month-based calendar can also take advantage of `:first_day` and `:min_days` to determine how to calculate weeks for month-based calendars too.

Here's how we define each of the three example calendars above:

```
defmodule Cldr.Calendar.US do
  use Cldr.Calendar.Base.Month,
    month_of_year: 10,          # The year starts in October
    min_days_in_first_week: 4,  # The first week of the year is that with at least 4 days of October in it
    day_of_week: 7              # When referring to weeks, Sunday is the first day
end

defmodule Cldr.Calendar.UK do
  use Cldr.Calendar.Base.Month,
    month_of_year: 4            # The fiscal year starts in April
end

defmodule Cldr.Calendar.AU do
  use Cldr.Calendar.Base.Month,
    month_of_year: 7,           # The fiscal year starts in July
    year: :ending               # A year refers to the ending Gregorian year.
                                # In this example, the Australian fiscal
                                # year 2017 is the year that starts in July
                                # 2016 and ends in June 2017
end
```

## Beginning and ending gregorian years

When we talk about the Gregorian calendar we refer to the 12 months from January to December. However when we consider the various fiscal calendars, the Gregorian starting date and the Gregorian ending date will often be in different years.

In these cases, when we say "the 2019 US Fiscal Year" what does that mean?  The US fiscal year starts in October. Now we need to know whether referring to the "the 2019 US Fiscal Year" means the year that ends in September 2019 or the year that starts in October 2019.

Some further examples are:

* The UK Fiscal Year starts in April. By convention, the Fiscal Year is the year that starts with April.

* The US Fiscal Year starts in October.  By convention , the Fiscal Year is the year that has the ending October in it.

* The Australian Fiscal Year starts in July. By convention, the Fiscal Year is the year that ends in July.

* The National Retail Federation has a calendar that starts on the Saturday nearest the end of January.  By convention, the Fiscal Year is the year of the starting Saturday.

To cater for these varying definitions of what a Fiscal Year means, a configuration option `:year` can be set to `:majority` (which is the default), `:beginning` and `:ending`.

* `:majority` means that the Fiscal Year is the year that has the most Gregorian months in it. This is the default.
* `:beginning` means that the Fiscal Year is the year in which the first Gregorian month is found.
* `:ending` means that the Fiscal Year is the year in which the last Gregorian month is found.

First lets consider the default `:majority` strategy.  This strategy says that the Fiscal Year is that year in which the majority of Gregorian months are found.

                            2018                      2019                      2020
                  J F M A M J J A S O N D | J F M A M J J A S O N D | J F M A M J J A S O N D |
                  . . . . . . . . . . . . | . . . . . . . . . . . . | . . . . . . . . . . . . |
    Majority
      Starts Jan                            <--------------------->
      Starts Mar                                <----------------------->
      Starts Jun                                      <----------------------->
      Starts Jul              <----------------------->
      Starts Oct                    <----------------------->

      Ends Dec                              <--------------------->
      Ends Feb                                  <----------------------->
      Ends May                                        <----------------------->
      Ends Jun                <----------------------->
      Ends Aug                    <----------------------->

From the diagram above we can define the following rules:

* For `:starts` calendars, we can say that the *starting* gregorian year is is the same as the *fiscal year* if the starting month is January through June inclusive. If the starting month is July through to December then the starting Gregorian year is the year *prior* to the *fiscal year*. Similarly, the *ending* Gregorian year is the *next* year for calendars that start in February through June and it's the *fiscal year* for calendars that start in July through December. Years that start in January end in January of the same year.

* For ":ends" calendars the rules are the opposite.

## Calendar Creation

Since calendars defined in `Cldr.Calendar` are intended to be compatible and convertible to other Calendars supporting Elixir's `Calendar` behaviour, the configuration of calendars needs to be encapsulated.

The simplest way to is to define a module that `use`s either `Cldr.Calendar.Base.Week` or `Cldr.Calendar.Base.Month`. This is how we have been defining calendar modules in the examples so far.

A calendar module can also be created at run time.  It is semantically identical to defining a static module but the module is built at run time rather than compile time. New calendars are created with the function `Cldr.Calendar.new/3`. For example:
```
iex> Cldr.Calendar.new :my_new_calendar, :week, first_or_last: :first, day_of_week: 1, min_days_in_first_week: 7
{:ok, :my_new_calendar}
```
Calendar functions are now available on the module `:my_new_calendar`.
```
iex> :my_new_calendar.
__config__/0
date_from_iso_days/1
date_to_iso_days/3
date_to_string/3
datetime_to_string/11
day_of_era/3
day_of_week/3
day_of_year/3
...
```

**CAUTION** Since the runtime creation of new calendars creates a new module and therefore a new atom, this function has the potential to surface an attack vector that could exhaust the atom table and crash the BEAM.  It is strongly recommended calendars be defined statically where possible. Never trust unfiltered user input to create a calendar.

### Fiscal Calendars for Territories

`Cldr Calendars` can create a fiscal year calendar for many territories (countries) based upon data from [the CIA world fact book](https://www.cia.gov/library/publications/the-world-factbook/fields/228.html).  To create a fiscal year calendar for a territory use the `Cldr.Calendar.FiscalYear.calendar_for/1` function.

```
 iex> Cldr.Calendar.FiscalYear.calendar_for("IS")
 {:ok, Cldr.Calendar.FiscalYear.IS}

 iex> Cldr.Calendar.FiscalYear.calendar_for("ZZ")
 {:error, {Cldr.UnknownTerritoryError, "The territory \"ZZ\" is unknown"}}

 iex> Cldr.Calendar.FiscalYear.calendar_for(:AF)
 {:error, {Cldr.UnknownCalendarError, "Fiscal calendar is unknown for :AF"}}
```

## Sigil ~d

`Cldr Calendars` provides a convenience sigil for the creation of dates in calendars. Note that it is necessary to import the `Cldr.Calendar.Sigils` module before using the `~d` sigil.
```
 iex> import Cldr.Calendar.Sigils

 # Create a date in the default Cldr.Calendar.Gregorian
 iex> ~d[2019-01-01]
 ~d[2019-01-01 Gregorian]

 # Inbuilt calendars can be referred to by their shortened form
 iex> ~d[2019-01-01 NRF]
 ~d[2019-W01-1 NRF]

 # Create a calendar and define a date in it
 iex> Cldr.Calendar.new FiscalAU, :month, month_of_year: 7
 {:ok, FiscalAU}
 iex> ~d[2019-01-01 FiscalAU]
 ~d[2019-01-01 FiscalAU]
 ```

## Date localization

`Cldr Calendars` is able to localize parts of a date include the `era`,
`quarter`, `month` and `day_of_week`.  The [CLDR](htts://cldr.unicode.org)
provides the underlying data.  The function `Cldr.Calendar.localize/3`
provides the required functionality. Some examples are:
```
 iex> Cldr.Calendar.localize ~D[2019-01-01], :era
 "AD"

 iex> Cldr.Calendar.localize ~D[2019-01-01], :day_of_week
 "Tue"

 iex> Cldr.Calendar.localize ~D[0001-01-01], :day_of_week
 "Mon"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :era
 "AD"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :quarter
 "Q2"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :month
 "Jun"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :day_of_week
 "Sat"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :day_of_week, format: :wide
 "Saturday"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :day_of_week, format: :narrow
 "S"

 iex> Cldr.Calendar.localize ~D[2019-06-01], :day_of_week, locale: "ar"
      "السبت"
```

## Calendar Intervals (date ranges)

Intervals representing parts of a calendar can be created and compared. Since intervals are represented as a `Date.Range` they can also be enumerated with the `Map` and `Stream` functions.

Intervals can be created for a year, quarter, month, week and day.  For example:

```elixir
  iex> Cldr.Calendar.Interval.year(2019)
  #DateRange<~d[2019-01-01 Gregorian], ~d[2019-12-31 Gregorian]>

  iex> Cldr.Calendar.Interval.month(2019, 3)
  #DateRange<~d[2019-03-01 Gregorian], ~d[2019-03-31 Gregorian]>

  iex> Cldr.Calendar.Interval.month(2019, 3, Cldr.Calendar.NRF)
  #DateRange<~d[2019-W10-1 NRF], ~d[2019-W13-7 NRF]>

  iex> Cldr.Calendar.Interval.week(2019, 5, Cldr.Calendar.NRF)
  #DateRange<~d[2019-W05-1 NRF], ~d[2019-W05-7 NRF]>

  iex> Cldr.Calendar.Interval.quarter(2019, 3)
  #DateRange<~d[2019-07-01 Gregorian], ~d[2019-09-30 Gregorian]>
```

### Comparing Calendar Intervals

Intervals can also be compared to each other and using the taxonomy of [Allen's Interval Algebra](https://en.wikipedia.org/wiki/Allen%27s_interval_algebra) a comparison will return one of 13 different relationship types between two calendar intervals:

  Relation	     | Inverse
  ----------     | --------------
  :precedes	     | :preceded_by
  :meets         | :met_by
  :overlaps      | :overlapped_by
  :finished_by   | :finishes
  :contains      | :during
  :starts        | :started_by
  :equals        | :equals

Some examples:

```elixir
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
```

### Durations

A duration is calculated as the difference in time in calendar units: years, months, days, hours, minutes, seconds and microseconds.

This is useful to support formatting a string for users in easy-to-understand terms. For example `11 months, 3 days and 4 minutes` is a lot easier to understand than `28771440` seconds.

The package [ex_cldr_units](https://hex.pm/packages/ex_cldr_units) can be optionally configured to provide localized formatting of durations.

If configured, the following providers must be configured in the appropriate CLDR backend module. For example:

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "ja"],
    providers: [Cldr.Calendar, Cldr.Number, Cldr.Unit, Cldr.List]
end
```

To create a duration, use `Cldr.Calendar.Duration.new/2` providing two dates, times or datetimes. The first date must occur before the second date.  Datetimes must be in the same time zone. To format a duration into a string use `Cldr.Calendar.Duration.to_string/2`.

An example is:
```elixir
iex> {:ok, duration} = Cldr.Calendar.Duration.new(~D[2019-01-01], ~D[2019-12-31])
iex> Cldr.Calendar.Duration.to_string(duration)
"11 months and 30 days"
```

A duration can also be created from a `Date.Range.t` and `CalendarInterval.t`. `CalendarInterval.t` is defined by the wonderful [calendar_interval](https://hex.pm/packages/calendar_interval) library.

```elixir
iex> Cldr.Calendar.Duration.new Date.range(~D[2020-01-01], ~D[2020-12-31])
{:ok,
 %Cldr.Calendar.Duration{
   day: 30,
   hour: 0,
   microsecond: 0,
   minute: 0,
   month: 11,
   second: 0,
   year: 0
 }}

iex> use CalendarInterval
CalendarInterval

iex> Cldr.Calendar.Duration.new ~I"2020-01/12"
{:ok,
 %Cldr.Calendar.Duration{
   day: 30,
   hour: 0,
   microsecond: 0,
   minute: 0,
   month: 11,
   second: 0,
   year: 0
 }}
```

A duration can be added to a date. Adding to times and datetimes is not currently supported. An example is:

```elixir
iex> {:ok, duration} = Cldr.Calendar.Duration.new(~D[2019-01-01], ~D[2019-12-31])
iex> Cldr.Calendar.plus ~D[2019-01-01], duration
~D[2019-12-31]
```

### Configuring a Cldr backend for localization

In order to localize date parts a `backend` module must be defined. This
is a module which hosts the CLDR data for a set of locales. The detailed
information for configuring a `backend` is [documented here](https://hexdocs.pm/ex_cldr/readme.html#configuration).

For a simple configuration the following steps may be used:

1. Create a backend module.
```
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "jp", "ar"],
    providers: [Cldr.Calendar, Cldr.Number]
end
```

2. Optionally configure this backend as the system default in your `config.exs`.
```
config :ex_cldr,
  default_backend: MyApp.Cldr
```

3. When creating a calendar a default backend may also be defined for this calendar.
```
defmodule MyCalendar do
  use Cldr.Calendar.Base.Month,
    month_of_year: 4,
    cldr_backend: MyApp.Cldr
end
```

It is also possible to pass the name of a backend module to the `Cldr.Calendar.localize/3` function by specifying the `:backend` option with a `backend` module name.

## Interesting calendar links

* [Why isn’t the new year on the winter solstice?](https://slj.ma/cal.html)




