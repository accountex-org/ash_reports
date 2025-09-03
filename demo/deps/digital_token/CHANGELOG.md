# Changelog

## Digital Token 1.0.0

This is the changelog for Digital Token version 1.0.0 released on September 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Bug Fixes

* Fix parsing error on some tokens from the updated registry.

### Enhancements

* Use the erlang `:json` module as a candidate JSON decoder if the underlying OTP release supports it (>= OTP 27).  This support also requires at least `cldr_utils` version 2.28.2.

## Digital Token 0.6.0

This is the changelog for Digital Token version 0.6.0 released on July 8th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Bug Fixes

* Remove checking Phoenix and Ecto json_library configurations.  Ecto no longer configures its `:json_library` in `config.exs` and checking for Phoenix configuration can cause config failures when [building in Docker](https://github.com/elixir-cldr/cldr/issues/208).

* Sort the short names for a token by their length so that the standard short name is the shortest one.

* Fix code that made an implicit assumption about map order.

### Enhancements

* Update to the latest toekn registry and symbol registry.

## Digital Token 0.5.0

This is the changelog for Digital Token version 0.5.0 released on June 22nd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Enhancements

* Make the JSON library configurable. Like `ex_cldr` it will also attempt to use the JSON library configured for `ex_cldr`, `ecto`, `phoenix` or if otherwise configured `Jason` or `Poison`.

## Digital Token 0.4.0

This is the changelog for Digital Token version 0.4.0 released on May 20th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Enhancements

* Parse and structure the downloaded digital token registry and digital token symbols at download time rather than compile time. This reduces the compile time significantly.

## Digital Token 0.3.0

This is the changelog for Digital Token version 0.3.0 released on May 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Enhancements

* Add `DigitalToken.short_name/1` to return the short name of the digital token. This is analogous to the currency code for a currency.

* Add `DigitalToken.long_name/1` to return the long name of the digital token. This is analogous to the name of a currency.

* Add `DigitalToken.symbol/2` to return a "currency" symbol for a digital token that will be used for number formatting in [ex_cldr_numbers](https://github.com/elixir-cldr/cldr_numbers) and [ex_money](https://github.com/kipcole9/money).

## Digital Token 0.2.0

This is the changelog for Digital Token version 0.2.0 released on May 9th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Bug Fixes

* Return only the token id from `DigitalToken.validate_token/1` when the argument is already a valid token identifier.

## Digital Token 0.1.0

This is the changelog for Digital Token version 0.1.0 released on May 8th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/digital_token/tags)

### Enhancements

* Initial release
