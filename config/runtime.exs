import Config

# Runtime configuration for production and environment-specific settings

# Typst runtime configuration
if config_env() != :test do
  config :ash_reports, :typst,
    binary_path: System.get_env("TYPST_BINARY_PATH", "/usr/local/bin/typst"),
    font_paths: System.get_env("FONT_PATHS", ""),
    pool_size: System.schedulers_online() * 2,
    timeout: String.to_integer(System.get_env("TYPST_TIMEOUT", "30000"))
end
