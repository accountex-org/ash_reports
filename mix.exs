defmodule AshReports.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_reports,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_core_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {AshReports.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support", "test/data"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:ash, "~> 3.0"},
      {:spark, "~> 2.2"},

      # CLDR dependencies for internationalization
      {:ex_cldr, "~> 2.40"},
      {:ex_cldr_numbers, "~> 2.33"},
      {:ex_cldr_dates_times, "~> 2.20"},
      {:ex_cldr_currencies, "~> 2.16"},
      {:ex_cldr_calendars, "~> 1.26"},

      # Translation dependencies
      {:gettext, "~> 0.24"},

      # Optional dependencies
      {:phoenix_live_view, "~> 0.20", optional: true},

      # Development and test dependencies
      {:sourceror, "~> 1.8", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_check, "~> 0.12", only: [:dev, :test]},

      # Typst integration dependencies
      {:typst, "~> 0.1.7"},
      {:file_system, "~> 1.0", only: [:dev, :test]},

      # Chart generation dependencies (Stage 3)
      {:contex, "~> 0.5.0"},
      {:statistics, "~> 0.6.3"},
      {:timex, "~> 3.7"},

      # Phase 5.1 - Interactive Data Visualization dependencies
      {:jason, "~> 1.4"},

      # Test dependencies
      {:mox, "~> 1.1", only: :test},
      {:faker, "~> 0.18", only: :test},
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:stream_data, "~> 1.0"},
      {:bypass, "~> 2.1", only: :test},
      {:phoenix_test, "~> 0.7.1", only: :test, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      "test.all": ["test", "credo --strict", "dialyzer"],
      "test.coverage": ["coveralls.html"]
    ]
  end

  defp package do
    [
      name: "ash_reports",
      description: "Comprehensive reporting extension for Ash Framework",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/your-org/ash_reports"
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/ash_reports",
      extras: [
        "README.md",
        # User Guides
        "guides/user/getting-started.md": [title: "Getting Started"],
        "guides/user/report-creation.md": [title: "Report Creation"],
        "guides/user/graphs-and-visualizations.md": [title: "Graphs and Visualizations"],
        "guides/user/advanced-features.md": [title: "Advanced Features"],
        "guides/user/integration.md": [title: "Integration"],
        "guides/user/performance-optimization.md": [title: "Performance Optimization"],
        # Developer Guides
        "guides/developer/architecture-overview.md": [title: "Architecture Overview"],
        "guides/developer/dsl-system.md": [title: "DSL System"],
        "guides/developer/data-loading.md": [title: "Data Loading Pipeline"],
        "guides/developer/rendering-system.md": [title: "Rendering System"],
        "guides/developer/layout-system.md": [title: "Layout System"],
        "guides/developer/chart-system.md": [title: "Chart System"],
        "guides/developer/typst-pdf-generation.md": [title: "PDF Generation"],
        "guides/developer/extending-ash-reports.md": [title: "Extending AshReports"]
      ],
      groups_for_extras: [
        "User Guides": ~r/guides\/user\/.*/,
        "Developer Guides": ~r/guides\/developer\/.*/
      ],
      groups_for_modules: [
        DSL: [
          AshReports.Dsl,
          AshReports.Dsl.Report,
          AshReports.Dsl.Band,
          AshReports.Dsl.Column
        ],
        Extensions: [
          AshReports.Domain,
          AshReports.Resource
        ],
        Transformers: ~r/AshReports.Transformers.*/,
        Renderers: ~r/AshReports.Renderers.*/,
        Internal: ~r/AshReports.*/
      ]
    ]
  end
end
