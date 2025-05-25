defmodule AshReports.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_reports,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:usage_rules, "~> 0.1"},
      {:ash_ai, "~> 0.1"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6.2", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
