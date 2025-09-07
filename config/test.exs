import Config

# Test-specific configuration
config :ash_reports,
  report_storage_path: "tmp/test_reports",
  cache_enabled: false,
  worker_pool_size: 1,
  max_concurrent_reports: 1

# Configure logger for tests
config :logger, level: :warning

# Speed up tests
config :bcrypt_elixir, :log_rounds, 1

# Configure PhoenixTest endpoint (for demo tests)
config :phoenix_test, :endpoint, AshReportsWeb.Endpoint

config :ash_reports, AshReportsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base",
  server: false
