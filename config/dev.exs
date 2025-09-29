import Config

# Development-specific configuration
config :ash_reports,
  debug_mode: true,
  report_storage_path: "tmp/reports",
  cache_enabled: false

# Typst development configuration
config :ash_reports, :typst,
  hot_reload: true,
  template_validation: :strict,
  debug_output: true

# Configure logger for development
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module, :function]

config :logger,
  level: :debug
