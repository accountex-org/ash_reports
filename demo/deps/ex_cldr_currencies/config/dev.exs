# In test mode we compile and test all locales
import Config

config :ex_cldr,
  default_locale: "en",
  default_backend: MyApp.Cldr
