# Changelog

## Cldr_Currencies v2.16.5

This is the changelog for Cldr_Currencies v2.16.5 released on May 20th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Return an error tuple if there is no display name available to `Cldr.Currency.display_name/2`. Thanks to @tanguilp for the report. Closes #17.

## Cldr_Currencies v2.16.4

This is the changelog for Cldr_Currencies v2.16.4 released on February 13th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Remove trailing RTL (right-to-left) marker in currency strings.

## Cldr_Currencies v2.16.3

This is the changelog for Cldr_Currencies v2.16.3 released on September 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix spec for `Cldr.Currency.currency_for_code/1`. Thanks to @Tw33t3r for the PR. Closes #16.

### Enhancements

* Require Elixir 1.12 as a minimum version.

## Cldr_Currencies v2.16.2

This is the changelog for Cldr_Currencies v2.16.2 released on July 30th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix spec for `Cldr.Currency.currencies_for_locale!/3`. Thanks to @AntoineAugusti for the PR. Closes #15.

## Cldr_Currencies v2.16.1

This is the changelog for Cldr_Currencies v2.16.1 released on April 23rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Add `config/prod.exs` so `MIX_ENV=prod` compilation succeeds. Thanks to @camelpunch for the report. Closes #49.

## Cldr_Currencies v2.16.0

This is the changelog for Cldr_Currencies v2.16.0 released on April 21st, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Update to [CLDR 45](https://cldr.unicode.org/index/downloads/cldr-45) data as used in `ex_cldr` version 2.38.0.

* Default the currency display name when there is no other pluralization data. This is required due to some data generation changes in the JSON data used by `ex_cldr`.

## Cldr_Currencies v2.15.1

This is the changelog for Cldr_Currencies v2.15.1 released on November 3rd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix compilation warnings on Elixir 1.16.

* Fixes typespec for `Cldr.Currency.currency_history_for_locale/1`. Thanks to @Munksgaard for the report and PR. Closes #11, Closes #12.

## Cldr_Currencies v2.15.0

This is the changelog for Cldr_Currencies v2.15.0 released on January 28th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Add `Cldr.Currency.current_territory_currencies/1` and `MyApp.Cldr.Currency.current_territory_currencies/0` that returns a mapping from territory code from currency type for all territories that have a current currency.  Thanks for @lawik for the inspiration.

## Cldr_Currencies v2.14.3

This is the changelog for Cldr_Currencies v2.14.3 released on January 27th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* `Cldr.Currency.current_currency_for_territory/1` returns `nil` if the territory, like `:AQ` has no currency. Thanks to @lawik for the report. Closes #8.

## Cldr_Currencies v2.14.2

This is the changelog for Cldr_Currencies v2.14.2 released on October 8th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix `Cldr.Currency.currency_strings/2` to include narrow symbols. Note that where duplicate symbols exist (same symbol for more than one currency) they are are omitted from the list of strings since they are ambiguous (unless one of them is a historic currency in which case the current currency is kept and the historic removed).

## Cldr_Currencies v2.14.1

This is the changelog for Cldr_Currencies v2.14.1 released on June 8th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix `Cldr.Currency.currency_from_locale/2` when the first argument is a `t:Cldr.LanguageTag.t/0`

## Cldr_Currencies v2.14.0

This is the changelog for Cldr_Currencies v2.14.0 released on June 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Add `Cldr.Currency.currency_for_code/2` and the same function for backend modules.

## Cldr_Currencies v2.13.0

This is the changelog for Cldr_Currencies v2.13.0 released on February 21st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix deprecated `use Mix.Config` and replace with `import Config` in configuration files.

### Enhancements

* Add `Cldr.Currency.currency_format_from_locale/2` support a binary language tag and optional backend

## Cldr_Currencies v2.12.0

This is the changelog for Cldr_Currencies v2.12.0 released on October 27th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Updates to support [CLDR release 40](https://cldr.unicode.org/index/downloads/cldr-40) via [ex_cldr version 2.24](https://hex.pm/packages/ex_cldr/2.24.0)

* Fix licence name

### Deprecations

* Don't call deprecated `Cldr.Config.known_locale_names/1`, call `Cldr.Locale.Loader.known_locale_names/1` instead.

## Cldr_Currencies v2.12.0-rc.1

This is the changelog for Cldr_Currencies v2.12.0-rc.1 released on October 25th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Deprecations

* Don't call deprecated `Cldr.Config.known_locale_names/1`, call `Cldr.Locale.Loader.known_locale_names/1` instead.

## Cldr_Currencies v2.12.0-rc.0

This is the changelog for Cldr_Currencies v2.12.0-rc.0 released on October 3rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Support for CLDR version 40.

## Cldr_Currencies v2.11.1

This is the changelog for Cldr_Currencies v2.11.1 released on August 4th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Add missing docs and specs. Thanks to @tcitworld for the report. Closes #5.

## Cldr_Currencies v2.11.0

This is the changelog for Cldr_Currencies v2.11.0 released on July 1st, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Adds support for the `Cldr.DisplayName` protocol for `t:Cldr.Currency` structs.

* Updated to [ex_cldr version 2.23.0](https://hex.pm/packages/ex_cldr/2.23.0) which changes the names of some of the field in the "-u-" extension to match the CLDR canonical name. In particular the field name `currency_format` changes to `cf`.

## Cldr_Currencies v2.10.1

This is the changelog for Cldr_Currencies v2.10.0 released on June 17th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug fixes

* Constrain `ex_doc` to `:dev` and `:release` environments only, and `:optional` to make sure.

## Cldr_Currencies v2.10.0

This is the changelog for Cldr_Currencies v2.10.0 released on June 17th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Allow `%Currency{}` structs in `currency_for_code/3`. Thanks to @jeroenvisser101 for the PR. [Improves the performance](https://github.com/elixir-cldr/cldr_currencies/pull/4) by up to 40x when validating currencies when the currency has already been pre-constructed.

* Add implementation of the `Inspect` protocol for `t:Cldr.Currency` structs.

## Cldr_Currencies v2.9.0

This is the changelog for Cldr_Currencies v2.9.0 released on April 8th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Depends upon `ex_cldr` version 2.20 which embodies CLDR39 data.

* Add `Cldr.Currency.display_name/2` that returns a localized display name suitable for use in UI applications.

* Add implementation of `String.Chars` and `Cldr.Chars` protocols for `t:Cldr.Currency` structs.

## Cldr_Currencies v2.9.0-rc.1

This is the changelog for Cldr_Currencies v2.9.0-rc.1 released on March 24th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Add `Cldr.Currency.display_name/2` that returns a localized display name suitable for use in UI applications.

* Add implementation of `String.Chars` and `Cldr.Chars` protocols for `t:Cldr.Currency` structs.

## Cldr_Currencies v2.9.0-rc.0

This is the changelog for Cldr_Currencies v2.9.0-rc.0 released on March 19th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Depends upon `ex_cldr` version 2.20 which embodies CLDR39 data.

## Cldr_Currencies v2.8.0

This is the changelog for Cldr_Currencies v2.8.0 released on November 1st, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Add support for [CLDR 38](http://cldr.unicode.org/index/downloads/cldr-38)

## Cldr_Currencies v2.7.0

This is the changelog for Cldr_Currencies v2.7.0 released on September 25th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Use `Cldr.default_backend!/0` when available since `Cldr.default_backend/0` is deprecated as of `ex_cldr` version `2.18.0`

## Cldr_Currencies v2.6.2

This is the changelog for Cldr_Currencies v2.6.2 released on August 31st, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Uses `Supervisor.child_spec/2` for `eternal` workers to remove deprecation warning on Elixir 1.11

## Cldr_Currencies v2.6.1

This is the changelog for Cldr_Currencies v2.6.1 released on July 19th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Make dialyzer happy. The `@spec`s for `Cldr.Eternal.start_link/1` and `Cldr.Eternal.start_link/0` however remain a mystery and are commented out for now - success typing seems happy nevertheless.

## Cldr_Currencies v2.6.0

This is the changelog for Cldr_Currencies v2.6.0 released on July 18th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Breaking change

* Remove `Cldr.Currency.make_currency_code/1` whose need is replaced by `Cldr.validate_currency/1`.

### Deprecations

* Deprecate `Cldr.Currency.known_currency?/1` in favour of `Cldr.Currency.known_currency_code?/1`

* Deprecate `Cldr.Currency.known_currencies/0` in favour of `Cldr.Currency.known_currency_codes/0`

### Enhancements

* Support the creation of private use currencies with `Cldr.Currency.new/2`. Newly created private use currencies are stored in an `:ets` table which means that currencies will need to be recreated on each application restart. Creating the currencies is a developer responsibility although this may change in the future.  In order to create currencies a supervisor and `:ets` table owner must be started.  See the [README](README.md) for further details on adding the private use currency store to your application supervision tree.

* Add `:alt_code` to the `Cldr.Currency` struct. When creating a new currency, the currency code must conform to ISO4217 meaning that any new code must be in the "private use" range. This in turn means that the currency code must start with "X" and be three characters long. Many crypto currencies have either conflicting currency codes (do not comply with ISO4217 private use) or are invalid codes (longer than three characters).  The `:alt_code` can be used to store an arbitrary alternative currency code than can be used to identify cryptocurrencies by a more familiar code.

## Cldr_Currencies v2.5.0

This is the changelog for Cldr_Currencies v2.5.0 released on May 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Add `Cldr.Currency.currency_from_locale/{1, 2}`

* Add `Cldr.Currency.current_currency_from_locale/1`

* Add `Cldr.Currency.current_currency_from_territory/1`

* Add `Cldr.Currency.currency_format_from_locale/1`

* Add `<backend>.currency_from_locale/{1, 2}`

## Cldr_Currencies v2.4,1

This is the changelog for Cldr_Currencies v2.4.1 released on November 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* In some rare cases, currency strings have a trailing `.`. These are now removed when producing currency strings that are used for parsing money amounts in `ex_money`.

## Cldr_Currencies v2.4.0

This is the changelog for Cldr_Currencies v2.4.0 released on November 6th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Adds the options `:only` and `:except` to `Cldr.Currency.filter_currencies/3`. These options are exercised in [ex_money](https://hex.pm/packages/ex_money) in the `Money.parse/2` function to limited parsed user input to a particular set of currencies.

## Cldr_Currencies v2.3.0

This is the changelog for Cldr_Currencies v2.3.0 released on March 28th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Updates to [CLDR version 35.0.0](http://cldr.unicode.org/index/downloads/cldr-35) released on March 27th 2019.

## Cldr_Currencies v2.2.5

This is the changelog for Cldr_Currencies v2.2.5 released on March 15th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix dialyzer warnings

## Cldr_Currencies v2.2.4

This is the changelog for Cldr_Currencies v2.2.4 released on March 15th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Makes generation of documentation for backend modules optional.  This is implemented by the `:generate_docs` option to the backend configuration.  The default is `true`. For example:

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    default_locale: "en-001",
    locales: ["en", "ja"],
    gettext: MyApp.Gettext,
    generate_docs: false
end
```

## Cldr_Currencies v2.2.3

This is the changelog for Cldr_Currencies v2.2.3 released on March 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix or silence all remaining dialyzer warnings for real this time

## Cldr_Currencies v2.2.2

This is the changelog for Cldr_Currencies v2.2.2 released on March 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix or silence all remaining dialyzer warnings

## Cldr_Currencies v2.2.1

This is the changelog for Cldr_Currencies v2.2.1 released on March 6th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fix or silence dialyzer warnings

## Cldr_Currencies v2.2.0

This is the changelog for Cldr_Currencies v2.2.0 released on February 23nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

This release adds mapping data from a territory to a list of currencies and functions to access them. This allows for identifying the current currency for a given locale.

* Adds `Cldr.Currency.currency_history_for_locale/2`
* Adds `Cldr.Currency.current_currency_for_locale/2`
* Adds `Cldr.Currency.territory_currencies/0`

Some examples:
```
iex> Cldr.Currency.territory_currencies |> Map.get("LT")
%{
  EUR: %{from: ~D[2015-01-01], to: nil},
  LTL: %{from: nil, to: ~D[2014-12-31]},
  LTT: %{from: nil, to: ~D[1993-06-25]},
  SUR: %{from: nil, to: ~D[1992-10-01]}
}

iex> Cldr.Currency.currency_history_for_locale "en", MyApp.Cldr
%{
  USD: %{from: ~D[1792-01-01], to: nil},
  USN: %{tender: false},
  USS: %{from: nil, tender: false, to: ~D[2014-03-01]}
}

iex> Cldr.Currency.current_currency_for_locale "en", MyApp.Cldr
:USD

iex> Cldr.Currency.current_currency_for_locale "en-AU", MyApp.Cldr
:AUD
```

## Cldr_Currencies v2.1.4

This is the changelog for Cldr_Currencies v2.1.4 released on February 22nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fixes significant performance regression in `Cldr.Currency.currencies_for_locale/2`.  Thanks to @doughsay for the issue.  Closes #98 in [money](https://github.com/elixir-cldr/money).

## Cldr_Currencies v2.1.3

This is the changelog for Cldr_Currencies v2.1.3 released on February 18th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Updates `ex_cldr` to fix the regex that parses currency names used for money parsing

## Cldr_Currencies v2.1.2

This is the changelog for Cldr_Currencies v2.1.2 released on February 13th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Some different currencies may have the same currency name.  This most commonly happens when there are historic currencies with the same name as a current currency. Afghan Afghanis, for example, has the code `:AFA` until 2002 when it was replaced by the currency code `:AFN`.  Now when extracting currency strings, the currency names map only to the current currency and the duplicated are therefore removed.

## Cldr_Currencies v2.1.1

This is the changelog for Cldr_Currencies v2.1.1 released on February 10th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Bug Fixes

* Fixes the regex for parsing currency names that have date ranges in them. It now correctly parses names with non-ASCII characters too.

* Removes `Cldr.Currency.all_currency_strings/2` since strings conflict across locales

* Add `Cldr.Currency.currency_strings/2`

### Enhancements

* Added `:unannotated` to `Cldr.Currency.currency_filter/2`.  It omits currency names that have a "(...)" in then since these are typically financial instruments.

## Cldr_Currencies v2.1.0

This is the changelog for Cldr_Currencies v2.1.0 released on February 9th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

The primary goal of this release is to provide a mechanism to support parsing money and currency input from a user. With this in mind, this release adds:

* `Cldr.Currency.currency_strings/2` that returns a list of strings for a currency in a locale against which user input can be compared to identify a currency

* `Cldr.Currency.all_currency_strings/2` which returns a similar list but for all known locales

* `Cldr.Currency.currency_filter/2` that will filter a list currencies based upon whether they are current, historic or legal tender

In addition the `Cldr.Currency.t` structure has changed:

* The `Cldr.Currency.t` struct now includes effective dates `:to` and `:from`.  These were previously encoded in the currency name.  The currency name no longer includes these dates.

## Cldr_Currencies v2.0.0

This is the changelog for Cldr_Currencies v2.0.0 released on November 22nd, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_currencies/tags)

### Enhancements

* Updated dependency on [ex_cldr](https://hex.pm/packages/ex_cldr) to version 2.0.0.
* Remove Poison from optional dependencies (can still be configured in a client app)

### Breaking Changes

* `Currency.currency_for_code/3` has a changed function signature and it now requires a backend module to be specified.  It also supports an option `:locale` to specify the locale. The default is the default locale of the specified backend.
```
  Cldr.Currency.currency_for_locale(:USD, MyApp.Cldr, locale: "en")
```
The @spec for the new signature is:
```
  @spec currency_for_code(code, Cldr.backend(), Keyword.t()) ::
          {:ok, t} | {:error, {module(), String.t()}}
```