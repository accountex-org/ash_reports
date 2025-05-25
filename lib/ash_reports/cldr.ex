defmodule AshReports.Cldr do
  @moduledoc """
  CLDR backend for AshReports providing internationalization support.
  
  This module configures locale-aware formatting for numbers, dates, times,
  and currencies used in report generation.
  """
  
  use Cldr,
    locales: ["en", "es", "fr", "de", "pt"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.DateTime, Cldr.Currency],
    generate_docs: false,
    suppress_warnings: true
end