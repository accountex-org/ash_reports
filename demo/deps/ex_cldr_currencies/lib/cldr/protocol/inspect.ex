defimpl Inspect, for: Cldr.Currency do
  def inspect(currency, _options) do
    "#Cldr.Currency<" <> inspect(currency.code) <> ">"
  end
end
