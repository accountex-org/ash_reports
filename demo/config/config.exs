import Config

# Configure AshReportsDemo application
config :ash_reports_demo,
  ets_data_layer: true,
  auto_generate_data: false

# Configure Ash Framework for demo
config :ash,
  default_page_type: :keyset,
  include_embedded_source_by_default?: false

# Configure data generator
config :ash_reports_demo, AshReportsDemo.DataGenerator,
  auto_start: true,
  default_volume: :medium

# Import environment specific config
import_config "#{config_env()}.exs"