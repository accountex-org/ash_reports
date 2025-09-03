import Config

# Test configuration for AshReportsDemo

# Disable auto data generation in tests (tests control their own data)
config :ash_reports_demo,
  auto_generate_data: false

# Configure data generator for tests
config :ash_reports_demo, AshReportsDemo.DataGenerator,
  auto_start: false,
  default_volume: :small

# Configure logger for tests
config :logger, level: :warning

# Configure Ash for tests
config :ash,
  disable_async?: true,
  missed_notifications: :ignore

# Configure ExUnit
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 1000
