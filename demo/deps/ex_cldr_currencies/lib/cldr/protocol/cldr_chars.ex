defimpl Cldr.Chars, for: Cldr.Currency do
  def to_string(currency) do
    locale = Cldr.get_locale()
    Cldr.Currency.display_name!(currency, locale: locale)
  end
end
