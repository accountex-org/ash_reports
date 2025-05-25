defmodule AshReports.Cldr do
  @moduledoc """
  CLDR backend for AshReports providing internationalization support.
  
  This module configures locale-aware formatting for numbers, dates, times,
  and currencies used in report generation.
  """
  
  use Cldr,
    locales: ["en", "es", "fr", "de", "pt", "ja", "zh", "ar", "ru", "it"],
    default_locale: "en",
    providers: [
      Cldr.Number,
      Cldr.Calendar,
      Cldr.DateTime,
      Cldr.Currency
    ],
    json_library: Jason
end