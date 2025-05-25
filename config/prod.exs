import Config

# Production-specific configuration
config :ash_reports,
  cache_enabled: true,
  cache_ttl: :timer.hours(1),
  worker_pool_size: System.schedulers_online() * 2,
  max_concurrent_reports: 50

# Configure logger for production
config :logger, level: :info