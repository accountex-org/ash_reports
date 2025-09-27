import Config

# Development configuration for AshReportsDemo

# Enable auto data generation in development
config :ash_reports_demo,
  auto_generate_data: true,
  dev_routes: true

# Disable PDF generation for development to avoid Chrome dependency issues
config :ash_reports,
  enable_pdf: false

# Configure data generator for development
config :ash_reports_demo, AshReportsDemo.DataGenerator,
  auto_start: true,
  default_volume: :medium,
  regenerate_on_start: false

# Configure the endpoint for development
config :ash_reports_demo, AshReportsDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "ash_reports_demo_dev_secret_key_base_for_development_only_change_in_production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:ash_reports_demo, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:ash_reports_demo, ~w(--watch)]}
  ]

# Enable live reload for development
config :ash_reports_demo, AshReportsDemoWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/ash_reports_demo_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable detailed logging for development
config :logger, level: :debug

# Configure Ash for development
config :ash,
  disable_async?: true,
  missed_notifications: :raise,
  validate_domain_resource_inclusion?: true
