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

# ex_check
config :ex_check,
  tools: [
    {:format, command: "mix format --check-formatted"},
    {:credo, command: "mix credo --strict"},
    {:dialyzer, command: "mix dialyzer", enable: System.get_env("RUN_DIALYZER") == "1"},
    {:test, command: "mix test"}
  ]

# git_hooks: run mix check on pre-commit
config :git_hooks,
  verbose: true,
  hooks: [
    pre_commit: [
      tasks: [
        {:cmd, "mix check"}
      ]
    ]
  ]

config :logger,
  level: :debug
