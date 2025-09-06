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

# Configure the endpoint
config :ash_reports_demo, AshReportsDemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: AshReportsDemoWeb.ErrorHTML, json: AshReportsDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AshReportsDemo.PubSub,
  live_view: [signing_salt: "ash_reports_demo_lv_salt"]

# Configure PhoenixTest
config :phoenix_test, :endpoint, AshReportsDemoWeb.Endpoint

# Configure esbuild for asset compilation
config :esbuild,
  version: "0.21.5",
  ash_reports_demo: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind for CSS compilation
config :tailwind,
  version: "3.4.0",
  ash_reports_demo: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
