# Changelog

**Note that `ex_cldr_calendars` version 1.24.0 and later are supported on Elixir 1.12 and later only.**

## Cldr.Calendars v1.26.4

This is the changelog for Cldr Calendars v1.26.4 released on December 29th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix day of week calculations when the config `%{day_of_week: :first}` is set.

* Improve the implementation of the fix for #23 to respect the conditional compilation based upon whether `ex_cldr_units` is configured or not.

## Cldr.Calendars v1.26.3

This is the changelog for Cldr Calendars v1.26.3 released on December 29th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix typing warning on Elixir 1.18. Thanks to @tjchambers for the report. Closes #23.

## Cldr.Calendars v1.26.2

This is the changelog for Cldr Calendars v1.26.2 released on September 12th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `Cldr.Calendar.Interval.compare/2` when the ranges overlap by one day. Thanks to @ArthurClemens for the report. Fixes #22.

## Cldr.Calendars v1.26.1

This is the changelog for Cldr Calendars v1.26.1 released on August 16th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix specs to suport dialyzer flags `:error_handling, :unknown, :underspecs, :extra_return, :missing_return`

## Cldr.Calendars v1.26.0

This is the changelog for Cldr Calendars v1.26.0 released on July 27th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Microseconds in `t:Cldr.Calendar.Duration.t/0` now follow the `t:Time.t/0` expectations.

### Enhancements

* Adds `Cldr.Calendar.Duration.new_from_seconds/1`

## Cldr.Calendars v1.25.2

This is the changelog for Cldr Calendars v1.25.2 released on July 9th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix spec for `Cldr.Calendar.localize/{1,2,3}` again - the return type was being aliased and hence dialyzer was unhappy. Not always, just sometimes.

## Cldr.Calendars v1.25.1

This is the changelog for Cldr Calendars v1.25.1 released on July 7th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix spec for `Cldr.Calendar.localize/{1,2,3}` to use the more expansive date/time/datetime types from `Cldr.Calendar`.

## Cldr.Calendars v1.25.0

This is the changelog for Cldr Calendars v1.25.0 released on July 7th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `Cldr.Calendar.Preference.calendar_from_locale/1` when `-u-ca-<calendar>` is specified as part of the locale.

### Enhancements

* This release provides initial support for partial dates.  Partial dates are those that do not have all of the fields `:year`, `:month`, `:day` and `:calendar`.  Not all functions require all parts of a date. And in some cases, like formatting just the year and the month, it shouldn't be necessary to provide data that has no use.  Of course many functions do require all fields be present - like adding a number of days to a date. In these cases, missing fields will cause an error to be returned. `ex_cldr_dates_times` version 2.19.0 and later take advantage of partial dates when formatting.

* Support `Cldr.Calendar.localize/3` option `era: :variant` to return an alternative localization. For instance, in the `:en` locale, this will return `CE` and `BCE` rather than the default `AD` and `BC`.

* Add `MyApp.Cldr.Calendar.localize/3` that delegates to `Cldr.Calendar.localize/3`.

## Cldr.Calendars v1.24.2

This is the changelog for Cldr Calendars v1.24.2 released on June 22nd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix runtime warning about `map.field` notation without parens when calling a function on Elixir 1.17.

## Cldr.Calendars v1.24.1

This is the changelog for Cldr Calendars v1.24.1 released on June 21st, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Compile on Elixir releases < 1.17. Some code in `Cldr.Calendar` depends on the new `t:Duration.t/0` struct which is only available on Elixir 1.17 or later. Elixir 1.16 is now added to the CI test matrix to ensure no future regression. Thanks to @WernerBuchert for the report. Closes #21.

## Cldr.Calendars v1.24.0

This is the changelog for Cldr Calendars v1.24.0 released on June 21st, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix compiler warnings for Elixir 1.17.

### Enhancements

* Adds new calendar callbacks `Calendar.shift_date/4`, `Calendar.shift_time/5` and `Calendar.shift_naive_datetime/8` supported in Elixir 1.17.

## Cldr.Calendars v1.23.1

This is the changelog for Cldr Calendars v1.23.1 released on March 1st, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* `Cldr.Calendar.plus/4` consistently applies a default for the `:coerce` option to `Cldr.Calendar.plus/4` and `Cldr.Calendar.minus/4`. The default is `true`. Previously the default for plus/minus months was `true` but the default for years was `false`. Thanks to @linusdm for raising the issue.

* Fix specs for `Cldr.Calendar.localize/{1..3}`. Thanks to @alappe for raising the issue. Closes #15.

## Cldr.Calendars v1.23.0

This is the changelog for Cldr Calendars v1.23.0 released on December 16th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

**Note that `ex_cldr_calendars` version 1.21.1 and later are supported on Elixir 1.11 and later only.**

### Breaking Change

* `Cldr.Calendar.weeks_in_year/1` now returns a tuple of the form `{weeks_in_year, days_in_last_week}` instead of an integer value. In particular for Gregorian based calendars, the value of `weeks_in_year` will be 53 and the value of `days_last_week` will be either `1` or `2` depending on whether it is a leap year or not.

### Enhancements

* Adds `:week` and `:day` to the options for `<calendar>.plus/5`. These are in addition to the already existing `:year`, `:quarter` and `:month` options. This addition is primarily to support [tempo](https://github.com/kipcole9/tempo). This enhancement has no affect on the public API in the `Cldr.Calendar` module. The bump in minor release number is to allow for `tempo` to target the appropriate version in a semver compatible manner.

* Adds `Cldr.Calendar.ISO` which is a month-based calendar with weeks that start on Monday and the first week must have at least 4 days of the current year in it. This aligns to the ISO8601 standard and is the month-based counterpart to the week-based `Cldr.Calendar.ISOWeek` calendar already included in `ex_cldr_calendars`.

## Cldr.Calendars v1.22.1

This is the changelog for Cldr Calendars v1.22.1 released on July 4th 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

**Note that `ex_cldr_calendars` version 1.21.1 and later are supported on Elixir 1.11 and later only.**

### Bug Fixes

* Compatibility with the `Calendar` behaviour changes in Elixir 1.15.

## Cldr.Calendars v1.22.0

This is the changelog for Cldr Calendars v1.22.0 released on April 28th 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

**Note that `ex_cldr_calendars` version 1.21.1 and later are supported on Elixir 1.11 and later only.**

### Bug Fixes

* Fixes localization of leap months which are used in lunisolar calendars.

### Enhancements

* Updates to [ex_cldr version 2.37.0](https://hex.pm/packages/ex_cldr/2.37.0) which includes data from [CLDR release 43](https://cldr.unicode.org/index/downloads/cldr-43)

* Supports configuring the `:cldr_calendar_name` for a calendar that is defined with the `Cldr.Calendar.Base.{Month, Week}` macros. The options can be `:gregorian` (the default) or `:japanese`. This change supports the new `ex_cldr_calendars_japanese` library.

## Cldr Calendars v1.21.0

This is the changelog for Cldr Calendars v1.21.0 released on October 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds modified Julian days conversions. Thanks to @polvalente for the PR. Closes #14.

## Cldr Calendars v1.20.0

This is the changelog for Cldr Calendars v1.20.0 released on September 21st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Doctests now reflect the new expression based inspection outputs in Elixir 1.14 for `t:Date.Range.t()`

* Improve the documentation for periods. Thanks to @alappe for the pull requests.

* Add `Cldr.Calendar.date_from_list/2` that takes a keyword list of time units and returns a `t:Date.t/0`

* Add `Cldr.Calendar.date_from_day_of_year/3` that returns a `t:Date.t/0` for the ordinal day of the year.

## Cldr Calendars v1.19.0

This is the changelog for Cldr Calendars v1.19.0 released on June 9th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `Cldr.Calendar.localize/{1,2}` that converts a date into the calendar associated with the provided locale.

## Cldr Calendars v1.18.1

This is the changelog for Cldr Calendars v1.18.1 released on June 5th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* `MyApp.Cldr.Calendar.calendar_from_locale/1` was added to the backend compiler module, not the backend module itself and therefore was not visible.

## Cldr Calendars v1.18.0

This is the changelog for Cldr Calendars v1.18.0 released on February 21st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Updates to [ex_cldr version 2.26.0](https://hex.pm/packages/ex_cldr/2.26.0) and [ex_cldr_numbers version 2.25.0](https://hex.pm/packages/ex_cldr_numbers/2.25.0) which use atoms for locale names and rbnf locale names. This is consistent with other elements of `t:Cldr.LanguageTag` where atoms are used when the cardinality of the data is fixed and relatively small and strings where the data is free format.

## Cldr Calendars v1.17.3

This is the changelog for Cldr Calendars v1.17.3 released on January 31st, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `Kday.nth_kday/3` for when the `kday` is the same as the day of the week of the date.

## Cldr Calendars v1.17.2

This is the changelog for Cldr Calendars v1.17.2 released on December 26th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fixes `Cldr.Calendar.FiscalYear.calendar_for/2`. Thanks for @DaTrader for the report. Closes #10.

* Use `Cldr.Calendar.date_to_iso_days/1` in preference to `Date.to_gregorian_days/1` since the latter is only available in Elixir 1.11 and later. Thanks to @DaTrader for the report. Closes #11.

## Cldr Calendars v1.17.1

This is the changelog for Cldr Calendars v1.17.1 released on November 1st, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Ensure compatibility with Elixir 1.13 by marking the implementations of `Calendar.year_of_era/1` as `@impl true` only on releases earlier than Elixir 1.13. In Elixir 1.13 the callback is `Calendar.year_of_era/3`.

## Cldr Calendars v1.17.0

This is the changelog for Cldr Calendars v1.17.0 released on October 27th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Updates to support [CLDR release 40](https://cldr.unicode.org/index/downloads/cldr-40) via [ex_cldr version 2.24](https://hex.pm/packages/ex_cldr/2.24.0)

* Add support for Chinese, Japanese and Korean [lunisolar calendars](https://github/elixir-cldr/cldr_calendars_lunisolar).

* Adds `Cldr.Calendar.year_of_era/1` that supports eras that might change at any time during a calendar year. This is primarily applicable to the Japanese calendar.

* Add `Cldr.Calendar.Behaviour` that can be `use`d to factor out a lot of calendar boilerplate for many (but not all) calendar types.

* Add `year_of_era/3` as a callback in the `Cldr.Calendar` behaviour. This is required because at least one calendar (the Japanese) can change era on any day of the year.

### Bug Fixes

* Fix `day_of_week/{3, 4}` to be compatible with Elixir 1.12 and also earlier versions - and ensure dialyzer passes on consuming applications.

### Deprecations

* Don't call deprecated `Cldr.Config.known_locale_names/1`, call `Cldr.Locale.Loader.known_locale_names/1` instead.

## Cldr Calendars v1.17.0-rc.3

This is the changelog for Cldr Calendars v1.17.0-rc.3 released on October 25th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Deprecations

* Don't call deprecated `Cldr.Config.known_locale_names/1`, call `Cldr.Locale.Loader.known_locale_names/1` instead.

## Cldr Calendars v1.17.0-rc.2

This is the changelog for Cldr Calendars v1.17.0-rc.2 released on October 25th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `day_of_week/{3, 4}` to be compatible with Elixir 1.12 and also earlier versions - and ensure dialyzer passes on consuming applications.

## Cldr Calendars v1.17.0-rc.1

This is the changelog for Cldr Calendars v1.17.0-rc.1 released on October 25th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Deprecations

* Don't call deprecated `Cldr.Config.get_locale/2`, use `Cldr.Locale.Loader.get_config/2` instead.

## Cldr Calendars v1.17.0-rc.0

This is the changelog for Cldr Calendars v1.17.0-rc.0 released on October 3rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Add support for Chinese, Japanese and Korean [lunisolar calendars](https://hex.pm/packages/ex_cldr_calendars_lunisolar).

* Adds `Cldr.Calendar.year_of_era/1` that supports eras that might change at any time during a calendar year. This is primarily applicable to the Japanese calendar.

* Add `Cldr.Calendar.Behaviour` that can be `use`d to factor out a lot of calendar boilerplate for many (but not all) calendar types.

* Add `year_of_era/3` as a callback in the `Cldr.Calendar` behaviour. This is required because at least one calendar (the Japanese) can change era on any day of the year.

## Cldr Calendars v1.16.0

This is the changelog for Cldr Calendars v1.16.0 released on August 27th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

**This release requires a minimum of Elixir 1.10 in line with supporting the current release and the two previous releases. Therefore Elixir 1.10, 1.11 and 1.12 are supported.**

### Bug Fixes

* Do not require `ex_cldr_numbers` as a dependency.

## Cldr Calendars v1.15.3

This is the changelog for Cldr Calendars v1.15.3 released on August 22nd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fixes a case when `Cldr.Calendar.Kday.kday_after/1` would return the same date, not the subsequent one.

## Cldr Calendars v1.15.2

This is the changelog for Cldr Calendars v1.15.2 released on August 20th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix doc errors. Thanks to @maennchen for the report. Doc errors in other `ex_cldr` packages are also updated.

## Cldr Calendars v1.15.1

This is the changelog for Cldr Calendars v1.15.1 released on August 8th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Add `Code.ensure_loaded?(Date)` when checking for whether we need to implement `Date.day_of_week/3` or `Date.day_of_week/4` since this changed from earlier Elixir versions.

## Cldr Calendars v1.15.0

This is the changelog for Cldr Calendars v1.15.0 released on July 1st, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Updated to [ex_cldr version 2.23.0](https://hex.pm/packages/ex_cldr/2.23.0) which has some changes to the valid territories list requiring a change in some tests. This normally wouldn't require a minor version change but doing so makes it easier to target this library as a dependency.

## Cldr Calendars v1.14.1

This is the changelog for Cldr Calendars v1.14.1 released on May 17th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `@impl` warnings on Elixir 1.12

## Cldr Calendars v1.14.0

This is the changelog for Cldr Calendars v1.14.0 released on April 13th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Support creating time-base durations that are negative in direction. Date and DateTime durations must still be positive durations. For example:
```elixir
# Create a time-based duration that is negative in direction
iex> {:ok, duration} = Cldr.Calendar.Duration.new ~T[10:00:00.0], ~T[09:00:00.0]
{:ok,
 %Cldr.Calendar.Duration{
   day: 0,
   hour: -1,
   microsecond: 0,
   minute: 0,
   month: 0,
   second: 0,
   year: 0
 }}
```

## Cldr Calendars v1.13.0

This is the changelog for Cldr Calendars v1.13.0 released on April 8th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Fix creating durations from two `Time`s.

* Add support for [CLDR 39](http://cldr.unicode.org/index/downloads/cldr-39) data release

## Cldr Calendars v1.12.1

This is the changelog for Cldr Calendars v1.12.1 released on April 7th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix a bug that prevented durations being created from times (as apposed to dates and datetimes)

## Cldr Calendars v1.12.0

This is the changelog for Cldr Calendars v1.12.0 released on November 8th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Rename `Cldr.Calendar.Preference.calendar_for_locale/1` to `Cldr.Calendar.Preference.calendar_from_locale/1`

* Rename `Cldr.Calendar.Preference.calendar_for_territory/1` to `Cldr.Calendar.Preference.calendar_from_territory/1`

* Add `Cldr.Calendar.calendar_from_territory/1`

* Add `Cldr.Calendar.calendar_from_locale/1,2`

## Cldr Calendars v1.11.0

This is the changelog for Cldr Calendars v1.11.0 released on November 1st, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Add support for [CLDR 38](http://cldr.unicode.org/index/downloads/cldr-38)

## Cldr Calendars v1.10.1

This is the changelog for Cldr Calendars v1.10.1 released on September 26th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Add a shim for `default_backend/0` that delegates to `Cldr.default_backend/0` or `Cldr.default_backend!/0` depending on `ex_cldr` release. Releases from `2.18.0` use `Cldr.default_backend!/0`.

## Cldr Calendars v1.10.0

This is the changelog for Cldr Calendars v1.10.0 released on August 29th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Supports upcoming Elixir 1.11.0.  The `Calendar` callback for `day_of_week/3` has been changed to `day_of_week/4` to allow for a different start day of week.  Since `Cldr Calendars` already supports defining calendars with different start days of the week (ie other than Monday), the implementation only supports the `:default` parameter. Thanks to @lostkobrakai for the report. Closes `Cldr Dates Times` issue #17.

## Cldr Calendars v1.9.0

This is the changelog for Cldr Calendars v1.9.0 released on June 7th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Add `Cldr.Calendar.plus/{3,4}` that allows adding a `Cldr.Calendar.Duration` to a `Calendar.date`. Support for adding durations to `datetime`s is not yet available.

* Add support for `datetimes` to `Cldr.Calendar.Duration.new/2`

* Add support for `Date.Range.t` and `CalendarInterval.t` to `Cldr.Calendar.Duration.new/1`

### Bug Fixes

* More complete test coverage on durations with some additional corner case fixes

## Cldr Calendars v1.8.1

This is the changelog for Cldr Calendars v1.8.1 released on June 4th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix duration calculation when the year and month are the same and the day of the last date is greater than the day of the first date

## Cldr Calendars v1.8.0

This is the changelog for Cldr Calendars v1.8.0 released on May 4th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking Change (that you might notice but probably won't)

* The `min_days_in_first_week` for the calendar `Cldr.Calendar.Gregorian` is changed to be `1` rather than the previous value of `4`. This only affects week-related processing for the calendar. The reason for the change is that the majority of territories have a preference for `1` for `min_days_in_first_week` so `Cldr.Calendar.Gregorian` more closely aligns to majority expectations.

### Breaking changes (that you shouldn't notice)

* The return result from `Cldr.Calendar.new/3` may return `{:module_already_exists, module}`. It previously returned `{:already_exists, module}`

### Bug Fixes

* Use `backend.get_locale/0` instead of `Cldr.get_locale/0` for all options

* Ensure that the default values for a locale's `min_days` and `first_day_of_week` are correctly applied in `Cldr.Calendar.new/3`. Any values passed as options take precedence over those defined for a locale.

### Enhancements

* Add `Cldr.Calendar.calendar_for_locale/2` which will create (or return) a gregorian-based calendar configured for the supplied locale. This typically means applying the correct values for `min_days` and `first_day_of_week`. For now all calendars created in this way are Gregorian monthly calendars.

* Add `Cldr.Calendar.Preference.calendar_for_locale/1` which returns the appropriate calendar for a locale based upon locale preferences and configured calendars. Unlike `Cldr.Calendar.calendar_for_locale/2`, this function may return non-Gregorian calendars. For example, for the locale `fa-IR` it will return `Cldr.Calendar.Persian` (if [ex_cldr_calendars_persian](https://hex.pm/packages/ex_cldr_calendars_persian) is configured) because that is the locale preference.

* Add `Cldr.Calendar.Preference.calendar_for_territory/1` provides the same result as `Cldr.Calendar.Preference.calendar_for_locale/2` except that argument is a territory code.

* Add `Cldr.Calendar.Preference.preferences_for_territory/1`

* Add `Cldr.Calendar.validate_calendar/1` which returns `{:ok, calendar}` if the argument is a `Cldr.Calendar` calendar module or `{:error, {exception, reason}}` if not.

## Cldr Calendars v1.7.1

This is the changelog for Cldr Calendars v1.7.1 released on January 26th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix doc link in `MyApp.Cldr.Calendar.strftime_options!/2`

## Cldr Calendars v1.7.0

This is the changelog for Cldr Calendars v1.7.0 released on January 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Remove call to deprecated `Code.ensure_compiled?/1` in Elixir 1.10

## Cldr Calendars v1.6.0

This is the changelog for Cldr Calendars v1.6.0 released on December 9th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds support for localizing Persian, Coptic and Ethiopic calendar localization. These calendars are published separately but they rely upon localization support from this package.

## Cldr Calendars v1.5.1

This is the changelog for Cldr Calendars v1.5.1 released on November 10th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix `Cldr.Calendar.next/3` and `Cldr.Calendar.previous/3` for months with week-based calendars. Thanks to @bglusman for the report. Closes #3. Note that the use of the `:coerce` option is recommended in most cases.

## Cldr Calendars v1.5.0

This is the changelog for Cldr Calendars v1.5.0 released on November 3rd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `MyApp.Cldr.Calendar.strftime_options!/2` to return a keyword list of options that can be applied to `NimbleStrftime.format/3`

## Cldr Calendars v1.4.0

This is the changelog for Cldr Calendars v1.4.0 released on September 14th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adjusts `<calendar>.add/3` to `<calendar>.add/5` so that it takes individual date and time elements and not formal structs.  This is consistent with other calendar behaviours.

## Cldr Calendars v1.3.0

This is the changelog for Cldr Calendars v1.3.0 released on September 1st, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

Adds `<calendar>.add/3` to add `:quarter` or `:week` to a naive datetime. This adds to the existing support for `:year` and `:month`.

## Cldr Calendars v1.2.0

This is the changelog for Cldr Calendars v1.2.0 released on August 31st, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `Cldr.Calendar.Duration` to create a duration struct defining the difference between two dates, times or date_times as a calendar difference in years, months, days, hours, minutes, seconds and microseconds. See `Cldr.Calendar.Duration.new/2` and `Cldr.Calendar.Duration.to_string/1`.

* Changes `sigil_d/2` from a function to a macro so that dates are created at compile time

## Cldr Calendars v1.1.0

This is the changelog for Cldr Calendars v1.1.0 released on August 30th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `<calendar>.add/3` to add `:year` or `:month` to a naive datetime.  This function supports the library [calendar_interval](https://hex.pm/packages/calendar_interval) allowing intervals to be used with `ex_cldr_calendars`[https://hex.pm/packages/ex_cldr_calendars]. The mid-term objective is to add `add/3` to the `Calendar` behaviour and thereby also simplify the interface to `CalendarInterval`.

* Changes the output of `to_string/1` to consistently use the full name of the calendar module, not an appreviated name.

## Cldr Calendars v1.0.0

This is the changelog for Cldr Calendars v1.0.0 released on June 16th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking changes

* The format produced by inspecting a Date (or DateTime or NaiveDateTime) has changed. The parsing of dates in `sigil_d` (the `~d` sigil) has also changed in order to facilitate roundtrip conversions. Previously a date would inspect as (using the NRF calendar) `~d[2019-W01-1]NRF`. It now inspects as `~d[2019-W01-1 NRF]`.  The same approach is used for all calendars.  See the examples in `Cldr.Calendar.Sigils`. This change is applicable to Elixir 1.10 and later.

* The calendar configuration option `:min_days` has been renamed `:min_days_in_first_week`. The configuration option `:day` has been renamed to `:day_of_week` and the option `:month` has been renamed to `:month_of_year`. An exception will be raised if existing calendars are not updated.

* An exception will be raised if a calendar is configured with an unknown option.

### Enhancements

* Implements `inspect_date/4`, `inspect_datetime/11`, `inspect_naive_datetime/8` and `inspect_time/5` for all `Cldr.Calendar` calendars.  This implementation supports the revised `Inspect` protocol implementation for `Date`, `Time`, `DateTime` and `NaiveDateTime` structs.  The purpose of that change is to allow customer calendars to be inspected. This change is applicable to Elixir 1.10 and later.

* Adds `Cldr.Calendar.week_of_month/1` and `Cldr.Calendar` callback `week_of_month/4` to return the week of a month. The weeks are calculated on the basis of the calendar configuration. As a result, the week of the month, like the week of the year, may be in a different Gregorian year and month compared to the specified date.

* Adds `Cldr.Calendar.weeks_in_year/1` to return the number of weeks in a year.

* Adds a calendar configuration where weeks start on the first day of the year. This configuration is valid only for `:month` based calendars.  The configuration option `day: :first` triggers this behaviour. This configuration can result in the last week of the year being less than 7 days.

* Adds `Cldr.Calendar.inspect/2` that can be used as an `:inspect_fun` option in `Inspect.Opts` for Elixir version 1.9.  It will not be required for Elixir 1.10 and later since [this commit](https://github.com/elixir-lang/elixir/commit/23a68035be96717ca5f8fd20355bdb7bc5ed38f8) introduces `inspect_*` callbacks for `Date`, `Time`, `DateTime` and `NaiveDateTime`. An `:inspect_fun` can be configured in `IEx` by:

```elixir
iex> IEx.configure(inspect: [inspect_fun: &Cldr.Calendar.inspect/2])
:ok
```

### Bug Fixes

* Ensure that `Cldr.Calendar` callbacks return a `Calendar.ISO` calendar if called with one (either as part of a date or as a separate argument).

* Ensure the return calendar types of a an Interval are `Calendar.ISO` is the date provided is `Calendar.ISO`

* Fix `Cldr.Calendar.plus/4` for `:months` when the month wraps into the previous year(s)

* Fix `sigil_d` to correctly parse ISO Week dates that have only a single digit day

## Cldr Calendars v0.9.0

This is the changelog for Cldr Calendars v0.9.0 released on June 9th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking changes

* Depends on Elixir 1.8 and above since it requires recent `Calendar` functionality.

## Cldr Calendars v0.8.0

This is the changelog for Cldr v0.8.0 released on June 8th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds option `:type` to `Cldr.Calendar.localize/3`. This determines the format type to be localized. The valid types are `:format` (the default) or `:stand_alone`.

* Add `Cldr.Calendar.day_periods/2` to support localization of the day periods of a time

* Add `Cldr.Calendar.default_calendar/0`. Returns `Cldr.Calendar.Gregorian`

* Add `Cldr.Calendar.default_cldr_calendar/0`. Returns `:gregorian`

## Cldr Calendars v0.7.0

This is the changelog for Cldr Calendars v0.7.0 released on June 1st, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking Changes

* Moved `year/1`, `quarter/1`, `month/1`, `week/1` and `day/1` to a new module `Cldr.Calendar.Interval`

### Enhancements

* Adds `Cldr.Calendar.Interval.compare/2` to compare two intervals (date ranges) using [Allen's Interval Algebra](https://en.wikipedia.org/wiki/Allen%27s_interval_algebra) taxonomy.

* Defaults the calendar to `Cldr.Calendar.Gregorian` for `Cldr.Calendar.Interval.year/2`, `Cldr.Calendar.Interval.quarter/3`, `Cldr.Calendar.Interval.month/3`, `Cldr.Calendar.Interval.week/3` and `Cldr.Calendar.Interval.day/3`

## Cldr Calendars v0.6.0

This is the changelog for Cldr Calendars v0.6.0 released on April 28th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Remove the need for [nimble_csv](https://hex.pm/nimble_csv) as a dependency

## Cldr Calendars v0.5.0

This is the changelog for Cldr Calendars v0.5.0 released on April 21th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking changes

* `Cldr.Calendar.localize/3` for `:days_of_week` now returns a list of 2-tuples that are of the format `{day_of_week, day_name}`.

### Enhancements

* Add `Cldr.Calendar.localize/6` which localises numbers as part of a date without parameter checking.  This is considered a private implementation for now.

## Cldr Calendars v0.4.1

This is the changelog for Cldr Calendars v0.4.1 released on April 19th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Bug Fixes

* Fix calculation of `days_in_month` for the last month in long year of a week-based calendar

## Cldr Calendars v0.4.0

This is the changelog for Cldr Calendars v0.4.0 released on April 19th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `Cldr.Calendar.interval_stream/3` which returns a stream function that when enumerated generates a list of dates with a specified precision of either `:years`, `:quarters`, `:months`, `:weeks` or `:days`. This function has the same arguments and generates the same results as `Cldr.Calendar.interval/3` except it generates the results lazily.

* Adds `:days_of_week` option to `Cldr.Calendar.localize/3` which returns a list of the localized names of the days of the week in calendar order.

* Adds `calendar_base/0` to identify whether the calendar is week or month based.

### Bug Fixes

* Fix `Cldr.Calendar.day_of_week/1` for week-based calendars

## Cldr Calendars v0.3.0

This is the changelog for Cldr Calendars v0.3.0 released on April 16th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Adds `Cldr.Calendar.interval/3` which generates an enumerable list of dates with a specified precision of either `:years`, `:quarters`, `:months`, `:weeks` or `:days`.

### Examples:
```
iex> import Cldr.Calendar.Sigils
Cldr.Calendar.Sigils

iex> d = ~d[2019-01-31]
%Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 1, year: 2019}

iex> d2 = ~d[2019-05-31]
%Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 5, year: 2019}

iex> Cldr.Calendar.interval d, 3, :months
[
  %Date{calendar: Cldr.Calendar.Gregorian, day: 28, month: 2, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 3, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 30, month: 4, year: 2019}
]

iex> Cldr.Calendar.interval d, d2, :months
[
  %Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 1, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 28, month: 2, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 3, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 30, month: 4, year: 2019},
  %Date{calendar: Cldr.Calendar.Gregorian, day: 31, month: 5, year: 2019}
]
```
## Cldr Calendars v0.2.0

This is the changelog for Cldr Calendars v0.2.0 released on April 14th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Breaking Changes

* All calendars now return `{year, month, day}` tuples from `date_from_iso_days/1`. Previously in some cases they returned a `Date.t`

* `first_day_of_year/1` and `last_day_of_year/1`, `first_gregorian_day_of_year/1` and `last_gregorian_day_of_year/1` now all return a `Date.t` or an error tuple.  Previously the returned result types were inconsistent.

* Remove `first_gregorian_day_of_year/1` and `last_gregorian_day_of_year/1` from `Cldr.Calendar` callbacks.

### Enhancements

* Adds `Cldr.Calendar.Julian` implementing the Julian calendar. This calendar does not implement `week/2`, `week_of_year/3` or `iso_week_of_year/3`.

### Bug Fixes

* Fixes calculating negative offsets for months in a week-based calendar.  Thanks to @bglusman. Closes #2.

## Cldr Calendars v0.1.0

This is the changelog for Cldr Calendars v0.1.0 released on April 5th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_calendars/tags)

### Enhancements

* Initial release.  See the README for a description of this project.