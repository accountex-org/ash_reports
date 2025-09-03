defmodule Cldr.Calendar.Preference do
  alias Cldr.LanguageTag

  @territory_preferences Cldr.Config.calendar_preferences()

  @doc false
  def territory_preferences do
    @territory_preferences
  end

  @doc false
  def preferences_for_territory(territory) do
    with {:ok, territory} <- Cldr.validate_territory(territory) do
      territory_preferences = territory_preferences()
      default_territory = Cldr.default_territory()
      the_world = Cldr.the_world()

      preferences =
        Map.get(territory_preferences, territory) ||
          Map.get(territory_preferences, default_territory) ||
          Map.get(territory_preferences, the_world)

      {:ok, preferences}
    end
  end

  @doc """
  Returns the calendar module preferred for
  a territory.

  ## Arguments

  * `territory` is any valid ISO3166-2 code as
    an `String.t` or upcased `atom()`

  ## Returns

  * `{:ok, calendar_module}` or

  * `{:error, {exception, reason}}`

  ## Examples

      iex> Cldr.Calendar.Preference.calendar_from_territory :US
      {:ok, Cldr.Calendar.US}

      iex> Cldr.Calendar.Preference.calendar_from_territory :YY
      {:error, {Cldr.UnknownTerritoryError, "The territory :YY is unknown"}}

  ## Notes

  The overwhelming majority of territories have
  `:gregorian` as their first preferred calendar
  and therefore `Cldr.Calendar.Gregorian`
  will be returned for most territories.

  Returning any other calendar module would require:

  1. That another calendar is preferred over `:gregorian`
     for a territory

  2. That a calendar module is available to support
     that calendar.

  As an example, Iran (territory `:IR`) prefers the
  `:persian` calendar. If the optional library
  [ex_cldr_calendars_persian](https://hex.pm/packages/ex_cldr_calendars_persian)
  is installed, the calendar module `Cldr.Calendar.Persian` will
  be returned. If it is not installed, `Cldr.Calendar.Gregorian`
  will be returned as `:gregorian` is the second preference
  for `:IR`.

  """
  def calendar_from_territory(territory) when is_atom(territory) do
    with {:ok, preferences} <- preferences_for_territory(territory),
         {:ok, calendar_module} <- find_calendar(preferences) do
      if calendar_module == Cldr.Calendar.default_calendar() do
        Cldr.Calendar.calendar_for_territory(territory)
      else
        {:ok, calendar_module}
      end
    end
  end

  def calendar_from_territory(territory, calendar) when is_atom(territory) do
    with {:ok, preferences} <- preferences_for_territory(territory),
         {:ok, calendar_module} <- find_calendar(preferences, calendar) do
      if calendar_module == Cldr.Calendar.default_calendar() do
        Cldr.Calendar.calendar_for_territory(territory)
      else
        {:ok, calendar_module}
      end
    end
  end

  @deprecated "Use calendar_from_territory/1"
  defdelegate calendar_for_territory(territory), to: __MODULE__, as: :calendar_from_territory

  defp find_calendar(preferences) do
    error = {:error, Cldr.unknown_calendar_error(preferences)}

    Enum.reduce_while(preferences, error, fn calendar, acc ->
      module = calendar_module(calendar)

      if Code.ensure_loaded?(module) do
        {:halt, {:ok, module}}
      else
        {:cont, acc}
      end
    end)
  end

  defp find_calendar(preferences, calendar) do
    if preferred = Enum.find(preferences, &(&1 == calendar)) do
      find_calendar([preferred])
    else
      find_calendar(preferences)
    end
  end

  @doc """
  Return the calendar module for a locale.

  ## Arguments

  * `:locale` is any locale or locale name validated
    by `Cldr.validate_locale/2`.  The default is
    `Cldr.get_locale()` which returns the locale
    set for the current process.

  ## Returns

  * `{:ok, calendar_module}` or

  * `{:error, {exception, reason}}`

  ## Examples

      iex> Cldr.Calendar.Preference.calendar_from_locale(:"en-GB")
      {:ok, Cldr.Calendar.GB}

      iex> Cldr.Calendar.Preference.calendar_from_locale("en-GB-u-ca-gregory")
      {:ok, Cldr.Calendar.Gregorian}

      iex> Cldr.Calendar.Preference.calendar_from_locale(:en)
      {:ok, Cldr.Calendar.US}

      iex> Cldr.Calendar.Preference.calendar_from_locale(:"fa-IR")
      {:ok, Cldr.Calendar.Persian}

      iex> Cldr.Calendar.Preference.calendar_from_locale("fa-IR-u-ca-gregory")
      {:ok, Cldr.Calendar.Gregorian}

  """
  def calendar_from_locale(locale \\ Cldr.get_locale())

  def calendar_from_locale(%LanguageTag{locale: %{calendar: nil}} = locale) do
    locale
    |> Cldr.Locale.territory_from_locale()
    |> calendar_from_territory
  end

  def calendar_from_locale(%LanguageTag{locale: %{calendar: calendar}} = locale) do
    calendar_module = Map.get(calendar_modules(), calendar)

    if calendar_module && Code.ensure_loaded?(calendar_module) do
      {:ok, calendar_module}
    else
      locale
      |> Cldr.Locale.territory_from_locale()
      |> calendar_from_territory(calendar)
    end
  end

  def calendar_from_locale(%LanguageTag{} = locale) do
    locale
    |> Cldr.Locale.territory_from_locale()
    |> calendar_from_territory
  end

  def calendar_from_locale(locale) when is_binary(locale) or is_atom(locale) do
    calendar_from_locale(locale, Cldr.default_backend!())
  end

  def calendar_from_locale(other) do
    {:error, Cldr.Locale.locale_error(other)}
  end

  def calendar_from_locale(locale, backend) when is_binary(locale) or is_atom(locale) do
    with {:ok, locale} <- Cldr.validate_locale(locale, backend) do
      calendar_from_locale(locale)
    end
  end

  @deprecated "Use calendar_from_locale/1"
  defdelegate calendar_for_locale(locale), to: __MODULE__, as: :calendar_from_locale

  @base_calendar Cldr.Calendar
  @known_calendars Cldr.known_calendars()

  @calendar_modules @known_calendars
                    |> Enum.map(fn c ->
                      {c,
                       Module.concat(@base_calendar, c |> Atom.to_string() |> Macro.camelize())}
                    end)
                    |> Map.new()

  def calendar_modules do
    @calendar_modules
  end

  def calendar_module(calendar) when calendar in @known_calendars do
    Map.fetch!(calendar_modules(), calendar)
  end

  def calendar_module(other) do
    {:error, Cldr.unknown_calendar_error(other)}
  end

  def calendar_from_name(name) do
    calendar_module = calendar_module(name)

    if Code.ensure_loaded?(calendar_module) do
      calendar_module
    else
      nil
    end
  end
end
