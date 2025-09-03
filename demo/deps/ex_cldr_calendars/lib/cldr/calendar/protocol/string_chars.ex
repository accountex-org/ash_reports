defimpl String.Chars, for: Cldr.Calendar.Duration do
  def to_string(duration) do
    locale = Cldr.get_locale()
    Cldr.Calendar.Duration.to_string!(duration, backend: locale.backend, locale: locale)
  end
end
