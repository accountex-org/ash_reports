defmodule AshReportsDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_reports_demo,
      version: "1.0.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AshReportsDemo.Application, []}
    ]
  end

  defp deps do
    [
      # Core Ash Framework
      {:ash, "~> 3.5"},
      {:ash_postgres, "~> 2.4"},

      # Phoenix Framework (for web capabilities if needed)
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:plug_cowboy, "~> 2.5"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.20"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # Data generation and testing
      {:faker, "~> 0.18"},
      {:decimal, "~> 2.0"},
      {:jason, "~> 1.4"},

      # PDF generation
      {:chromic_pdf, "~> 1.17"},

      # Development and testing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},

      # Test helpers
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.0"},
      {:phoenix_test, "~> 0.7.1", only: :test, runtime: false},
      # Main AshReports library (path dependency to parent project)
      {:ash_reports, path: "../"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      test: ["test"],
      "test.coverage": ["coveralls.html"],
      generate_data: ["run -e 'AshReportsDemo.DataGenerator.generate_sample_data(:medium)'"],
      demo: ["run -e 'AshReportsDemo.InteractiveDemo.start()'"]
    ]
  end
end
