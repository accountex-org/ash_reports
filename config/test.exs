import Config

# Test-specific configuration
config :ash_reports,
  report_storage_path: "tmp/test_reports",
  cache_enabled: false,
  worker_pool_size: 1,
  max_concurrent_reports: 1,
  # Disable ChromicPDF for tests to avoid Chrome dependency
  disable_pdf_generation: true

# Configure CLDR backend for tests
config :ex_cldr,
  default_backend: AshReports.Cldr

# Configure logger for tests
config :logger, level: :warning

# Speed up tests
config :bcrypt_elixir, :log_rounds, 1
