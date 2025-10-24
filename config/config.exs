import Config

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :resource,
        :reportable,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :resources,
        :reports,
        :policies,
        :authorization,
        :domain,
        :execution
      ]
    ]
  ]

# Configure AshReports defaults
config :ash_reports,
  default_formats: [:html, :pdf],
  report_storage_path: "priv/reports",
  cache_ttl: :timer.minutes(15),
  worker_pool_size: 5,
  max_concurrent_reports: 10

# Typst configuration
config :ash_reports, :typst,
  template_dir: "priv/typst_templates",
  cache_enabled: true,
  max_cache_size: 100,
  timeout: :timer.seconds(30)

# ChromicPDF configuration for PDF generation
if Code.ensure_loaded?(ChromicPDF) do
  config :chromic_pdf,
    session_pool: [size: 2],
    offline: true,
    print_to_pdf: %{
      margin_top: "0.5in",
      margin_bottom: "0.5in",
      margin_left: "0.5in",
      margin_right: "0.5in"
    }
end

# Configure PhoenixTest endpoint (required at compile time)
if Mix.env() == :test do
  config :phoenix_test, :endpoint, AshReports.TestEndpoint
end
