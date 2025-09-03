import Config

# Development configuration for AshReportsDemo

# Enable auto data generation in development
config :ash_reports_demo,
  auto_generate_data: true

# Configure data generator for development
config :ash_reports_demo, AshReportsDemo.DataGenerator,
  auto_start: true,
  default_volume: :medium,
  regenerate_on_start: false

# Enable detailed logging for development
config :logger, level: :debug

# Configure Ash for development
config :ash,
  disable_async?: true,
  missed_notifications: :raise,
  validate_domain_resource_inclusion?: true