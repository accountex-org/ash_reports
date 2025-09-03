defmodule Cldr.Currency.Backend do
  @moduledoc false

  def define_currency_module(config) do
    require Cldr
    require Cldr.Currency

    module = inspect(__MODULE__)
    backend = config.backend
    config = Macro.escape(config)

    quote location: :keep, bind_quoted: [module: module, backend: backend, config: config] do
      defmodule Currency do
        unless Cldr.Config.include_module_docs?(config.generate_docs) do
          @moduledoc false
        end

        @doc """
        Returns a `Currency` struct created from the arguments.

        ## Arguments

        * `currency` is a private use currency code in a format defined by
          [ISO4217](https://en.wikipedia.org/wiki/ISO_4217)
          which is `X` followed by two alphanumeric characters.

        * `options` is a map of options representing the optional elements of
          the `Cldr.Currency.t` struct.

        ## Options

        * `:name` is the name of the currency. Required.
        * `:digits` is the precision of the currency. Required.
        * `:symbol` is the currency symbol. Optional.
        * `:narrow_symbol` is an alternative narrow symbol. Optional.
        * `:round_nearest` is the rounding precision such as `0.05`. Optional.
        * `:alt_code` is an alternative currency code for application use.
        * `:cash_digits` is the precision of the currency when used as cash. Optional.
        * `:cash_rounding_nearest` is the rounding precision when used as cash
          such as `0.05`. Optional.

        ## Returns

        * `{:ok, Cldr.Currency.t}` or

        * `{:error, {exception, message}}`

        ## Example

            iex> #{inspect(__MODULE__)}.new(:XAE, name: "Custom Name", digits: 0)
            {:ok,
             %Cldr.Currency{
               alt_code: :XAE,
               cash_digits: 0,
               cash_rounding: nil,
               code: :XAE,
               count: %{other: "Custom Name"},
               digits: 0,
               from: nil,
               iso_digits: 0,
               name: "Custom Name",
               narrow_symbol: nil,
               rounding: 0,
               symbol: "XAE",
               tender: false,
               to: nil
             }}
            iex> MyApp.Cldr.Currency.new(:XAH, name: "Custom Name")
            {:error, "Required options are missing. Required options are [:name, :digits]"}
            iex> #{inspect(__MODULE__)}.new(:XAE, name: "XAE", digits: 0)
            {:error, {Cldr.CurrencyAlreadyDefined, "Currency :XAE is already defined."}}

        """
        @spec new(Cldr.Currency.code(), map() | Keyword.t()) ::
                {:ok, Cldr.Currency.t()} | {:error, {module(), String.t()}}

        def new(currency, options \\ [])

        def new(currency, options) do
          Cldr.Currency.new(currency, options)
        end

        @doc """
        Returns the appropriate currency display name for the `currency`, based
        on the plural rules in effect for the `locale`.

        ## Arguments

        * `number` is an integer, float or `Decimal`

        * `currency` is any currency returned by `Cldr.Currency.known_currencies/0`

        * `options` is a keyword list of options

        ## Options

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`. The
          default is `#{inspect(backend)}.get_locale/0`

        ## Returns

        * `{:ok, plural_string}` or

        * `{:error, {exception, message}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.pluralize(1, :USD)
            {:ok, "US dollar"}

            iex> #{inspect(__MODULE__)}.pluralize(3, :USD)
            {:ok, "US dollars"}

            iex> #{inspect(__MODULE__)}.pluralize(12, :USD, locale: "zh")
            {:ok, "美元"}

            iex> #{inspect(__MODULE__)}.pluralize(12, :USD, locale: "fr")
            {:ok, "dollars des États-Unis"}

            iex> #{inspect(__MODULE__)}.pluralize(1, :USD, locale: "fr")
            {:ok, "dollar des États-Unis"}

        """
        @spec pluralize(pos_integer, atom, Keyword.t()) ::
                {:ok, String.t()} | {:error, {module(), String.t()}}

        def pluralize(number, currency, options \\ []) do
          Cldr.Currency.pluralize(number, currency, unquote(backend), options)
        end

        @doc """
        Returns a list of all known currency codes.

        ## Example

            iex> #{inspect(__MODULE__)}.known_currency_codes()

        """
        @spec known_currency_codes() :: [Cldr.Currency.code(), ...]
        def known_currency_codes do
          Cldr.Currency.known_currency_codes()
        end

        @deprecate "Use #{inspect(__MODULE__)}.known_currency_codes/0"
        defdelegate known_currencies, to: __MODULE__, as: :known_currency_codes

        @doc """
        Returns a boolean indicating if the supplied currency code is known.

        ## Arguments

        * `currency_code` is a `binary` or `atom` representing an ISO4217
          currency code

        ## Returns

        * `true` or `false`

        ## Examples

            iex> #{inspect(__MODULE__)}.known_currency_code?("AUD")
            true

            iex> #{inspect(__MODULE__)}.known_currency_code?("GGG")
            false

            iex> #{inspect(__MODULE__)}.known_currency_code?(:XCV)
            false

        """
        @spec known_currency_code?(Cldr.Currency.code()) :: boolean
        def known_currency_code?(currency_code) do
          Cldr.Currency.known_currency_code?(currency_code)
        end

        @doc """
        Returns a 2-tuple indicating if the supplied currency code is known.

        ## Arguments

        * `currency_code` is a `binary` or `atom` representing an ISO4217
          currency code

        ## Returns

        * `{:ok, currency_code}` or

        * `{:error, {exception, reason}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.known_currency_code("AUD")
            {:ok, :AUD}

            iex> #{inspect(__MODULE__)}.known_currency_code("GGG")
            {:error, {Cldr.UnknownCurrencyError, "The currency \\"GGG\\" is invalid"}}

        """
        @spec known_currency_code(Cldr.Currency.code()) ::
                {:ok, Cldr.Currency.code()} | {:error, {module, String.t()}}

        def known_currency_code(currency_code) do
          Cldr.Currency.known_currency_code(currency_code)
        end

        @deprecate "Use #{inspect(__MODULE__)}.known_currency_code?/0"
        defdelegate known_currency?(code), to: __MODULE__, as: :known_currency_code?

        @doc """
        Returns the effective currency for a given locale

        ## Arguments

        * `locale` is a `Cldr.LanguageTag` struct returned by
          `Cldr.Locale.new!/2`

        ## Returns

        * A ISO 4217 currency code as an upcased atom

        ## Examples

            iex> {:ok, locale} = #{inspect(backend)}.validate_locale("en")
            iex> #{inspect(__MODULE__)}.currency_from_locale locale
            :USD

            iex> {:ok, locale} = #{inspect(backend)}.validate_locale("en-AU")
            iex> #{inspect(__MODULE__)}.currency_from_locale locale
            :AUD

            iex> #{inspect(__MODULE__)}.currency_from_locale("en-GB")
            :GBP

        """

        def currency_from_locale(%LanguageTag{} = locale) do
          Cldr.Currency.currency_from_locale(locale)
        end

        def currency_from_locale(locale) when is_binary(locale) do
          Cldr.Currency.currency_from_locale(locale, unquote(backend))
        end

        @doc """
        Returns the currency metadata for the requested currency code.

        ## Arguments

        * `currency_or_currency_code` is a `binary` or `atom` representation
           of an ISO 4217 currency code, or a `%Cldr.Currency{}` struct.

        ## Options

        * `:locale` is any valid locale name returned by `Cldr.known_locale_names/1`
          or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

        ## Returns

        * A `{:ok, currency}` or

        * `{:error, {exception, reason}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.currency_for_code("AUD")
            {:ok,
              %Cldr.Currency{
                cash_digits: 2,
                cash_rounding: 0,
                code: "AUD",
                count: %{one: "Australian dollar", other: "Australian dollars"},
                digits: 2,
                iso_digits: 2,
                name: "Australian Dollar",
                narrow_symbol: "$",
                rounding: 0,
                symbol: "A$",
                tender: true
            }}

            iex> #{inspect(__MODULE__)}.currency_for_code("THB")
            {:ok,
              %Cldr.Currency{
                cash_digits: 2,
                cash_rounding: 0,
                code: "THB",
                count: %{one: "Thai baht", other: "Thai baht"},
                digits: 2,
                iso_digits: 2,
                name: "Thai Baht",
                narrow_symbol: "฿",
                rounding: 0,
                symbol: "THB",
                tender: true
            }}

        """
        @spec currency_for_code(Cldr.Currency.code() | Cldr.Currency.t(), Keyword.t()) ::
                {:ok, Cldr.Currency.t()} | {:error, {module(), String.t()}}

        def currency_for_code(
              currency_or_currency_code,
              options \\ [locale: unquote(backend).default_locale()]
            ) do
          Cldr.Currency.currency_for_code(currency_or_currency_code, unquote(backend), options)
        end

        @doc """
        Returns the currency metadata for the requested currency code.

        ## Arguments

        * `currency_or_currency_code` is a `binary` or `atom` representation
           of an ISO 4217 currency code, or a `%Cldr.Currency{}` struct.

        ## Options

        * `:locale` is any valid locale name returned by `Cldr.known_locale_names/1`
          or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

        ## Returns

        * A `t:Cldr.Current.t/0` or

        * raises an exception

        ## Examples

            iex> #{inspect(__MODULE__)}.currency_for_code!("AUD")
            %Cldr.Currency{
              cash_digits: 2,
              cash_rounding: 0,
              code: "AUD",
              count: %{one: "Australian dollar", other: "Australian dollars"},
              digits: 2,
              iso_digits: 2,
              name: "Australian Dollar",
              narrow_symbol: "$",
              rounding: 0,
              symbol: "A$",
              tender: true
            }

            iex> #{inspect(__MODULE__)}.currency_for_code!("THB")
            %Cldr.Currency{
              cash_digits: 2,
              cash_rounding: 0,
              code: "THB",
              count: %{one: "Thai baht", other: "Thai baht"},
              digits: 2,
              iso_digits: 2,
              name: "Thai Baht",
              narrow_symbol: "฿",
              rounding: 0,
              symbol: "THB",
              tender: true
            }

        """
        @doc since: "2.14.0"

        @spec currency_for_code!(Cldr.Currency.code() | Cldr.Currency.t(), Keyword.t()) ::
                Cldr.Currency.t() | no_return()

        def currency_for_code!(
              currency_or_currency_code,
              options \\ [locale: unquote(backend).default_locale()]
            ) do
          Cldr.Currency.currency_for_code!(currency_or_currency_code, unquote(backend), options)
        end

        defp get_currency_metadata(code, nil) do
          string_code = to_string(code)

          {:ok, meta} =
            new(code,
              name: string_code,
              symbol: string_code,
              narrow_symbol: string_code,
              count: %{other: string_code}
            )

          meta
        end

        defp get_currency_metadata(_code, meta) do
          meta
        end

        @doc """
        Returns a map of the metadata for all currencies for
        a given locale.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_map}` or

        * `{:error, {exception, reason}}`

        ## Example

          MyApp.Cldr.Currency.currencies_for_locale("en")
          => {:ok,
           %{
             FJD: %Cldr.Currency{
               cash_digits: 2,
               cash_rounding: 0,
               code: "FJD",
               count: %{one: "Fijian dollar", other: "Fijian dollars"},
               digits: 2,
               from: nil,
               iso_digits: 2,
               name: "Fijian Dollar",
               narrow_symbol: "$",
               rounding: 0,
               symbol: "FJD",
               tender: true,
               to: nil
             },
             SUR: %Cldr.Currency{
               cash_digits: 2,
               cash_rounding: 0,
               code: "SUR",
               count: %{one: "Soviet rouble", other: "Soviet roubles"},
               digits: 2,
               from: nil,
               iso_digits: nil,
               name: "Soviet Rouble",
               narrow_symbol: nil,
               rounding: 0,
               symbol: "SUR",
               tender: true,
               to: nil
             },
             ...
            }}

        """
        @spec currencies_for_locale(
                Cldr.Locale.locale_reference(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()
              ) ::
                {:ok, map()} | {:error, {module(), String.t()}}

        def currencies_for_locale(locale, only \\ :all, except \\ nil)

        @doc """
        Returns a map that matches a currency string to a
        currency code.

        A currency string is a localised name or symbol
        representing a currency in a locale-specific manner.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_string_map}` or

        * `{:error, {exception, reason}}`

        ## Example

            MyApp.Cldr.Currency.currency_strings("en")
            => {:ok,
             %{
               "mexican silver pesos" => :MXP,
               "sudanese dinar" => :SDD,
               "bad" => :BAD,
               "rsd" => :RSD,
               "swazi lilangeni" => :SZL,
               "zairean new zaire" => :ZRN,
               "guyanaese dollars" => :GYD,
               "equatorial guinean ekwele" => :GQE,
               ...
              }}

        """
        @spec currency_strings(
                Cldr.Locale.locale_reference(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()
              ) ::
                {:ok, map()} | {:error, {module(), String.t()}}

        @rtl "\u200F"

        def currency_strings(locale, only \\ :all, except \\ nil)

        for locale_name <- Cldr.Locale.Loader.known_locale_names(config) do
          currencies =
            locale_name
            |> Cldr.Config.currencies_for!(config)
            |> Enum.map(fn {k, v} -> {k, struct(Cldr.Currency, v)} end)
            |> Map.new()

          currency_strings =
            for {currency_code, currency} <- currencies do
              strings =
                [currency.name, currency.symbol, currency.code]
                |> Kernel.++(Map.values(currency.count))
                |> Enum.reject(&is_nil/1)
                |> Enum.map(&String.downcase/1)
                |> Enum.map(&String.trim_trailing(&1, @rtl))
                |> Enum.map(&String.trim_trailing(&1, "."))
                |> Enum.uniq()

              {currency_code, strings}
            end

          inverted_currency_strings =
            Cldr.Currency.invert_currency_strings(currency_strings)
            |> Cldr.Currency.remove_duplicate_strings(currencies)
            |> Map.new()
            |> Cldr.Currency.add_unique_narrow_symbols(currencies)

          def currencies_for_locale(
                %LanguageTag{cldr_locale_name: unquote(locale_name)},
                only,
                except
              ) do
            filtered_currencies =
              unquote(Macro.escape(currencies))
              |> Cldr.Currency.currency_filter(only, except)

            {:ok, filtered_currencies}
          end

          def currency_strings(%LanguageTag{cldr_locale_name: unquote(locale_name)}, :all, nil) do
            {:ok, unquote(Macro.escape(inverted_currency_strings))}
          end
        end

        def currencies_for_locale(locale_name, only, except) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currencies_for_locale(locale, only, except)
          end
        end

        def currencies_for_locale(locale, _only, _except) do
          {:error, Cldr.Locale.locale_error(locale)}
        end

        def currency_strings(locale_name, only, except) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currency_strings(locale, only, except)
          end
        end

        def currency_strings(%LanguageTag{} = locale, only, except) do
          with {:ok, currencies} <- currencies_for_locale(locale) do
            filtered_currencies =
              currencies
              |> Cldr.Currency.currency_filter(only, except)

            currency_codes =
              filtered_currencies
              |> Map.keys()

            strings =
              locale
              |> currency_strings!
              |> Enum.filter(fn {_k, v} -> v in currency_codes end)
              |> Cldr.Currency.remove_duplicate_strings(filtered_currencies)
              |> Map.new()

            {:ok, strings}
          end
        end

        def currency_strings(locale, _only, _except) do
          {:error, Cldr.Locale.locale_error(locale)}
        end

        @doc """
        Returns a mapping from a territory code to its
        current currency code.

        If a territory has no current currency (like
        Antartica, territory code `:AQ`) then no
        mapping is returned for that territory.

        ## Returns

        * A map of `{territory_code => Cldr.Currency.t}`

        ## Example

            iex> #{inspect(__MODULE__)}.current_territory_currencies()

        """
        @doc since: "2.15.0"

        @spec current_territory_currencies() :: %{
                Cldr.Locale.territory_code() => Cldr.Currency.code()
              }
        def current_territory_currencies do
          Cldr.Currency.current_territory_currencies()
        end

        @doc """
        Returns a map of the metadata for all currencies for
        a given locale and raises on error.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_map}` or

        * raises an exception

        ## Example

          MyApp.Cldr.Currency.currencies_for_locale!("en")
          => %{
            FJD: %Cldr.Currency{
              cash_digits: 2,
              cash_rounding: 0,
              code: "FJD",
              count: %{one: "Fijian dollar", other: "Fijian dollars"},
              digits: 2,
              from: nil,
              iso_digits: 2,
              name: "Fijian Dollar",
              narrow_symbol: "$",
              rounding: 0,
              symbol: "FJD",
              tender: true,
              to: nil
            },
            SUR: %Cldr.Currency{
              cash_digits: 2,
              cash_rounding: 0,
              code: "SUR",
              count: %{one: "Soviet rouble", other: "Soviet roubles"},
              digits: 2,
              from: nil,
              iso_digits: nil,
              name: "Soviet Rouble",
              narrow_symbol: nil,
              rounding: 0,
              symbol: "SUR",
              tender: true,
              to: nil
            },
            ...
           }

        """
        @spec currencies_for_locale!(
                Cldr.Locale.locale_name() | LanguageTag.t(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()
              ) ::
                map() | no_return()

        def currencies_for_locale!(locale, only \\ :all, except \\ nil) do
          case currencies_for_locale(locale, only, except) do
            {:ok, currencies} -> currencies
            {:error, {exception, reason}} -> raise exception, reason
          end
        end

        @doc """
        Returns a map that matches a currency string to a
        currency code or raises an exception.

        A currency string is a localised name or symbol
        representing a currency in a locale-specific manner.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_string_map}` or

        * raises an exception

        ## Example

            MyApp.Cldr.Currency.currency_strings!("en")
            => %{
              "mexican silver pesos" => :MXP,
              "sudanese dinar" => :SDD,
              "bad" => :BAD,
              "rsd" => :RSD,
              "swazi lilangeni" => :SZL,
              "zairean new zaire" => :ZRN,
              "guyanaese dollars" => :GYD,
              "equatorial guinean ekwele" => :GQE,
              ...
             }

        """
        @spec currency_strings!(
                Cldr.LanguageTag.t() | Cldr.Locale.locale_name(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()
              ) ::
                map() | no_return()

        def currency_strings!(locale_name, only \\ :all, except \\ nil) do
          case currency_strings(locale_name, only, except) do
            {:ok, currency_strings} -> currency_strings
            {:error, {exception, reason}} -> raise exception, reason
          end
        end

        @doc """
        Returns the strings associated with a currency
        in a given locale.

        ## Arguments

        * `currency` is an ISO4217 currency code

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Returns

        * A list of strings or

        * `{:error, {exception, reason}}`

        ## Example

            iex> MyApp.Cldr.Currency.strings_for_currency(:AUD, "en")
            ...> |> Enum.sort()
            ["a$", "aud", "australian dollar", "australian dollars"]

        """
        def strings_for_currency(currency, locale) do
          Cldr.Currency.strings_for_currency(currency, locale, unquote(backend))
        end

        @doc """
        Returns a list of historic and the current
        currency for a given locale.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Example

            iex> MyApp.Cldr.Currency.currency_history_for_locale("en")
            {:ok,
                %{
                USD: %{from: ~D[1792-01-01], to: nil},
                USN: %{tender: false},
                USS: %{from: nil, tender: false, to: ~D[2014-03-01]}
              }
            }

        """
        @spec currency_history_for_locale(LanguageTag.t() | Cldr.Locale.locale_name()) ::
                {:ok, map()} | {:error, {module(), String.t()}}

        def currency_history_for_locale(%LanguageTag{} = language_tag) do
          Cldr.Currency.currency_history_for_locale(language_tag)
        end

        def currency_history_for_locale(locale_name) when is_binary(locale_name) do
          Cldr.Currency.currency_history_for_locale(locale_name, unquote(backend))
        end

        @doc """
        Returns the current currency for a given locale.

        This function does not consider the `U` extenion
        parameters `cu` or `rg`. It is recommended to us
        `Cldr.Currency.currency_from_locale/1` in most
        circumstances.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Example

            iex> MyApp.Cldr.Currency.current_currency_from_locale("en")
            :USD

            iex> MyApp.Cldr.Currency.current_currency_from_locale("en-AU")
            :AUD

        """
        def current_currency_from_locale(%LanguageTag{} = locale) do
          Cldr.Currency.current_currency_from_locale(locale)
        end

        def current_currency_from_locale(locale_name) when is_binary(locale_name) do
          Cldr.Currency.current_currency_from_locale(locale_name, unquote(backend))
        end
      end
    end
  end
end
